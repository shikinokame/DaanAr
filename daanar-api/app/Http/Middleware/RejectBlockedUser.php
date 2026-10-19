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

        // 2. Fallback: check X-User-Phone header (sent when token was already revoked on block)
        if (! $user && $request->hasHeader('X-User-Phone')) {
            $normalizedPhone = User::normalizePhoneNumber((string) $request->header('X-User-Phone'));
            $user = User::where('phone_number', $normalizedPhone)->first();
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

        return $next($request);
    }
}
