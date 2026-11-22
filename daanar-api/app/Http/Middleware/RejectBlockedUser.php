<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RejectBlockedUser
{
    /**
     * Reject API requests from mobile users whose account status is 'Blocked'.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // 1. Check authenticated Sanctum token user first
        $user = $request->user('sanctum');

        // 2. Fallback: check X-User-Phone header (sent by mobile app on every request)
        if (! $user && $request->hasHeader('X-User-Phone')) {
            $normalizedPhone = User::normalizePhoneNumber((string) $request->header('X-User-Phone'));
            if (preg_match('/^\+639\d{9}$/', $normalizedPhone)) {
                $user = User::where('phone_number', $normalizedPhone)->first();
                if (! $user) {
                    $maskedLabel = User::maskPhone($normalizedPhone);
                    $user = User::create([
                        'name'         => User::ROLE_NORMAL_USER . " ($maskedLabel)",
                        'email'        => null,
                        'phone_number' => $normalizedPhone,
                        'password'     => \Illuminate\Support\Facades\Hash::make(\Illuminate\Support\Str::random(32)),
                        'role'         => User::ROLE_NORMAL_USER,
                        'user_role'    => User::ROLE_NORMAL_USER,
                        'status'       => 'Active',
                    ]);
                }
            }
        }

        // 3. Fallback: check userId / user_id in request payload
        if (! $user) {
            $payloadUserId = $request->input('userId', $request->input('user_id'));
            if ($payloadUserId && is_numeric($payloadUserId)) {
                $user = User::find((int) $payloadUserId);
            }
        }

        if ($user && strtolower((string) $user->status) === 'blocked') {
            $user->tokens()->delete();

            return response()->json([
                'status'  => 'Blocked',
                'message' => 'This mobile number has been blocked by an administrator.',
            ], 403);
        }

        if ($user) {
            \Illuminate\Support\Facades\Auth::setUser($user);
            $request->setUserResolver(fn () => $user);
        } elseif ($request->is('api/v1/routes/compute')) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        return $next($request);
    }
}
