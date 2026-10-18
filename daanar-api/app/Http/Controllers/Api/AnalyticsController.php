<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Landmark;
use App\Models\LandmarkVisit;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AnalyticsController extends Controller
{
    /**
     * POST /api/v1/analytics/log-event (also aliased at /api/analytics/log-event)
     *
     * Accepts camelCase or snake_case payloads:
     * { userId, landmarkId, actionType, verificationMethod, userLat, userLng, deviceId }
     */
    public function logEvent(Request $request): JsonResponse
    {
        $userId = $request->input('userId', $request->input('user_id'))
            ?? $request->user('sanctum')?->id;
        $landmarkId = $request->input('landmarkId', $request->input('landmark_id'));
        $actionType = strtoupper((string) $request->input('actionType', $request->input('action_type', 'AR_VIEW')));
        $verificationMethod = $request->input('verificationMethod', $request->input('verification_method'));
        $userLat = $request->input('userLat', $request->input('user_lat'));
        $userLng = $request->input('userLng', $request->input('user_lng'));
        $deviceId = $request->input('deviceId', $request->input('device_id'));

        if (! $landmarkId || ! Landmark::whereKey($landmarkId)->exists()) {
            return response()->json([
                'message' => 'A valid landmarkId is required.',
            ], 422);
        }

        if (! in_array($actionType, LandmarkVisit::ALLOWED_ACTIONS, true)) {
            return response()->json([
                'message' => 'Invalid actionType. Allowed: ' . implode(', ', LandmarkVisit::ALLOWED_ACTIONS),
            ], 422);
        }

        if ($userId && ! User::whereKey($userId)->exists()) {
            $userId = null;
        }

        // Anti-Spam / Deduplication Rule for PHYSICAL_VISIT:
        // Prevent duplicate PHYSICAL_VISIT logs from the same user_id for the same landmark_id within 1 hour
        if ($actionType === LandmarkVisit::ACTION_PHYSICAL_VISIT && $userId) {
            $recentDuplicate = LandmarkVisit::where('landmark_id', $landmarkId)
                ->where('user_id', $userId)
                ->where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT)
                ->where('created_at', '>=', now()->subHour())
                ->first();

            if ($recentDuplicate) {
                return response()->json([
                    'status'       => 'deduplicated',
                    'log_id'       => $recentDuplicate->id,
                    'action_type'  => $recentDuplicate->action_type,
                    'user_id'      => $recentDuplicate->user_id,
                    'landmark_id'  => $recentDuplicate->landmark_id,
                ], 200);
            }
        }

        $sourceMap = [
            LandmarkVisit::ACTION_PHYSICAL_VISIT => 'geofence',
            LandmarkVisit::ACTION_AR_VIEW        => 'ar_view',
            LandmarkVisit::ACTION_MAP_NAV        => 'map_nav',
            LandmarkVisit::ACTION_PAGE_VIEW      => 'page_view',
        ];

        $visit = LandmarkVisit::create([
            'landmark_id'         => (int) $landmarkId,
            'user_id'             => $userId ? (int) $userId : null,
            'action_type'         => $actionType,
            'verification_method' => $verificationMethod ?: ($actionType === LandmarkVisit::ACTION_PHYSICAL_VISIT ? 'GPS_GEOFENCE' : 'REMOTE'),
            'user_lat'            => is_numeric($userLat) ? (float) $userLat : null,
            'user_lng'            => is_numeric($userLng) ? (float) $userLng : null,
            'device_id'           => $deviceId ?: ($userId ? "user_{$userId}" : null),
            'source'              => $sourceMap[$actionType] ?? 'app',
            'visited_at'          => now(),
        ]);

        return response()->json([
            'status'      => 'recorded',
            'log_id'      => $visit->id,
            'user_id'     => $visit->user_id,
            'landmark_id' => $visit->landmark_id,
            'action_type' => $visit->action_type,
        ], 201);
    }

    /**
     * GET /api/v1/admin/reports?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD
     */
    public function reports(Request $request): JsonResponse
    {
        $startDate = $request->query('startDate')
            ? Carbon::parse($request->query('startDate'))->startOfDay()
            : null;
        $endDate = $request->query('endDate')
            ? Carbon::parse($request->query('endDate'))->endOfDay()
            : null;

        $applyDateFilter = function ($q) use ($startDate, $endDate) {
            if ($startDate) {
                $q->where('created_at', '>=', $startDate);
            }
            if ($endDate) {
                $q->where('created_at', '<=', $endDate);
            }
        };

        // Top Summary Card KPIs
        $physicalQuery = LandmarkVisit::where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT);
        $applyDateFilter($physicalQuery);
        $totalPhysicalVisits = (clone $physicalQuery)->count();

        $todayPhysicalVisits = LandmarkVisit::where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT)
            ->whereDate('created_at', today())
            ->count();

        // Unique visitors: distinct registered user_id across visits in range (fallback to distinct user_id across all logs if no physical visits yet)
        $uniqueVisitorsQuery = LandmarkVisit::whereNotNull('user_id');
        $applyDateFilter($uniqueVisitorsQuery);
        $uniquePhysicalVisitors = (clone $uniqueVisitorsQuery)
            ->where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT)
            ->distinct('user_id')
            ->count('user_id');
        $uniqueAllActiveVisitors = (clone $uniqueVisitorsQuery)
            ->distinct('user_id')
            ->count('user_id');
        $uniqueVisitors = $uniquePhysicalVisitors > 0 ? $uniquePhysicalVisitors : $uniqueAllActiveVisitors;

        $arQuery = LandmarkVisit::where('action_type', LandmarkVisit::ACTION_AR_VIEW);
        $applyDateFilter($arQuery);
        $totalArViews = (clone $arQuery)->count();

        $todayArViews = LandmarkVisit::where('action_type', LandmarkVisit::ACTION_AR_VIEW)
            ->whereDate('created_at', today())
            ->count();

        // Landmark Visit Analytics Table Rows
        $joinClosure = function ($join) use ($startDate, $endDate) {
            $join->on('landmarks.id', '=', 'landmark_visits.landmark_id');
            if ($startDate) {
                $join->where('landmark_visits.created_at', '>=', $startDate);
            }
            if ($endDate) {
                $join->where('landmark_visits.created_at', '<=', $endDate);
            }
        };

        $rows = Landmark::query()
            ->with('municipality')
            ->leftJoin('landmark_visits', $joinClosure)
            ->select([
                'landmarks.id',
                'landmarks.name',
                'landmarks.municipality_id',
                'landmarks.category',
                DB::raw("COUNT(CASE WHEN landmark_visits.action_type = 'PHYSICAL_VISIT' THEN 1 END) as total_physical_visits"),
                DB::raw("COUNT(DISTINCT CASE WHEN landmark_visits.action_type = 'PHYSICAL_VISIT' THEN landmark_visits.user_id END) as unique_visitors"),
                DB::raw("COUNT(CASE WHEN landmark_visits.action_type = 'AR_VIEW' THEN 1 END) as viewed_in_ar"),
                DB::raw("COUNT(DISTINCT CASE WHEN landmark_visits.action_type = 'AR_VIEW' THEN landmark_visits.user_id END) as unique_ar_viewers"),
                DB::raw("COUNT(CASE WHEN landmark_visits.action_type = 'MAP_NAV' THEN 1 END) as map_navigations"),
                DB::raw("MAX(landmark_visits.created_at) as last_visited_at"),
            ])
            ->groupBy('landmarks.id', 'landmarks.name', 'landmarks.municipality_id', 'landmarks.category')
            ->orderByDesc('total_physical_visits')
            ->orderByDesc('viewed_in_ar')
            ->get();

        $topSite = $rows->sortByDesc('total_physical_visits')->first();
        if (! $topSite || (int) $topSite->total_physical_visits === 0) {
            $topSite = $rows->sortByDesc('viewed_in_ar')->first();
        }

        return response()->json([
            'summary' => [
                'totalPhysicalVisits' => (int) $totalPhysicalVisits,
                'todayPhysicalVisits' => (int) $todayPhysicalVisits,
                'uniqueVisitors'      => (int) $uniqueVisitors,
                'uniquePhysicalVisitors' => (int) $uniquePhysicalVisitors,
                'totalArViews'        => (int) $totalArViews,
                'todayArViews'        => (int) $todayArViews,
                'mostVisitedSite'     => ($topSite && ((int) $topSite->total_physical_visits > 0 || (int) $topSite->viewed_in_ar > 0))
                    ? $topSite->name
                    : '—',
            ],
            'landmarks' => $rows->map(fn ($r) => [
                'landmarkId'          => $r->id,
                'landmarkName'        => $r->name,
                'municipality'        => $r->municipality?->name,
                'category'            => $r->category,
                'totalPhysicalVisits' => (int) $r->total_physical_visits,
                'uniqueVisitors'      => (int) $r->unique_visitors,
                'viewedInAr'          => (int) $r->viewed_in_ar,
                'uniqueArViewers'     => (int) $r->unique_ar_viewers,
                'mapNavigations'      => (int) $r->map_navigations,
                'lastVisitedAt'       => $r->last_visited_at,
            ])->values(),
        ]);
    }

    /**
     * GET /api/v1/admin/users
     */
    public function users(): JsonResponse
    {
        $users = User::query()
            ->withCount([
                'visits as total_physical_visits' => fn ($q) => $q->where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT),
                'visits as total_ar_views' => fn ($q) => $q->where('action_type', LandmarkVisit::ACTION_AR_VIEW),
            ])
            ->latest()
            ->get()
            ->map(fn (User $u) => [
                'userId'              => $u->id,
                'name'                => $u->name,
                'email'               => $u->email,
                'maskedPhoneNumber'   => User::maskPhone($u->phone_number),
                'phoneNumber'         => $u->phone_number,
                'userRole'            => $u->user_role ?? $u->role,
                'status'              => $u->status ?? 'Active',
                'totalPhysicalVisits' => (int) $u->total_physical_visits,
                'totalArViews'        => (int) $u->total_ar_views,
                'registeredAt'        => $u->created_at?->toIso8601String(),
            ]);

        return response()->json(['data' => $users]);
    }

    /**
     * PATCH /api/v1/admin/users/{user}/status
     */
    public function updateUserStatus(Request $request, User $user): JsonResponse
    {
        $validated = $request->validate([
            'status' => ['required', 'string', 'in:Active,Blocked,active,blocked'],
        ]);

        $user->status = ucfirst(strtolower($validated['status']));
        $user->save();

        if ($user->status === 'Blocked') {
            $user->tokens()->delete();
        }

        return response()->json([
            'data' => [
                'userId' => $user->id,
                'status' => $user->status,
            ],
        ]);
    }
}

