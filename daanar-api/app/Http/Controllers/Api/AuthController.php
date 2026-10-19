<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\LoginRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * POST /api/v1/auth/login
     * Returns a Sanctum token on valid credentials.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        if (strtolower((string) $user->status) === 'blocked') {
            return response()->json([
                'message' => 'Your account has been blocked by an administrator.',
            ], 403);
        }

        // Revoke all previous tokens to enforce single-session
        $user->tokens()->delete();

        $token = $user->createToken('api-token')->plainTextToken;

        return response()->json([
            'data' => [
                'token' => $token,
                'token_type' => 'Bearer',
                'user' => [
                    'id'           => $user->id,
                    'user_id'      => $user->id,
                    'name'         => $user->name,
                    'email'        => $user->email,
                    'phone_number' => $user->phone_number,
                    'role'         => $user->role,
                    'user_role'    => $user->user_role ?? $user->role,
                    'status'       => $user->status ?? 'Active',
                ],
            ],
        ]);
    }

    /**
     * POST /api/v1/auth/register-mobile
     * Registers or retrieves a mobile app user by Philippine mobile number & role.
     */
    public function registerMobile(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'phone_number' => ['required', 'string', 'max:32'],
            // Optional: all mobile visitors share one role ("Normal User").
            // Legacy values (Tourist/Student/Educator) from older APK builds are still accepted.
            'user_role'    => ['nullable', 'string', 'max:32'],
            'name'         => ['nullable', 'string', 'max:255'],
        ]);

        $normalizedPhone = User::normalizePhoneNumber($validated['phone_number']);

        // Validate normalized Philippine mobile format (+639XXXXXXXXX)
        if (! preg_match('/^\+639\d{9}$/', $normalizedPhone)) {
            throw ValidationException::withMessages([
                'phone_number' => ['Please enter a valid Philippine mobile number (e.g., 09171234567 or +639171234567).'],
            ]);
        }

        $roleNormalized = User::ROLE_NORMAL_USER;

        $user = User::where('phone_number', $normalizedPhone)->first();

        if ($user) {
            if (strtolower((string) $user->status) === 'blocked') {
                return response()->json([
                    'message' => 'This mobile number has been blocked by an administrator.',
                ], 403);
            }

            // Update role if user changed it
            $user->user_role = $roleNormalized;
            if (! in_array($user->role, ['super_admin', 'admin', 'officer'], true)) {
                $user->role = $roleNormalized;
            }
            if (! empty($validated['name'])) {
                $user->name = $validated['name'];
            }
            $user->save();
        } else {
            $maskedLabel = User::maskPhone($normalizedPhone);
            $user = User::create([
                'name'         => $validated['name'] ?? "$roleNormalized ($maskedLabel)",
                'email'        => null,
                'phone_number' => $normalizedPhone,
                'password'     => Hash::make(Str::random(32)),
                'role'         => $roleNormalized,
                'user_role'    => $roleNormalized,
                'status'       => 'Active',
            ]);
        }

        $token = $user->createToken('mobile-token')->plainTextToken;

        return response()->json([
            'data' => [
                'token'      => $token,
                'token_type' => 'Bearer',
                'user_id'    => $user->id,
                'user'       => [
                    'id'           => $user->id,
                    'user_id'      => $user->id,
                    'name'         => $user->name,
                    'phone_number' => $user->phone_number,
                    'masked_phone' => User::maskPhone($user->phone_number),
                    'user_role'    => $user->user_role ?? $user->role,
                    'status'       => $user->status ?? 'Active',
                ],
            ],
        ]);
    }

    /**
     * GET /api/v1/auth/me
     * Verifies the mobile user's current account status (Active vs Blocked).
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user('sanctum');

        if (! $user) {
            $rawPhone = $request->query('phone_number') ?? $request->header('X-User-Phone');
            if ($rawPhone) {
                $normalizedPhone = User::normalizePhoneNumber((string) $rawPhone);
                $user = User::where('phone_number', $normalizedPhone)->first();
            }
        }

        if (! $user) {
            $userId = $request->query('user_id');
            if ($userId && is_numeric($userId)) {
                $user = User::find((int) $userId);
            }
        }

        if (! $user) {
            return response()->json([
                'status'  => 'Unregistered',
                'message' => 'Account not found. Please register your mobile number.',
            ], 401);
        }

        if (strtolower((string) $user->status) === 'blocked') {
            $user->tokens()->delete();

            return response()->json([
                'status'  => 'Blocked',
                'message' => 'This mobile number has been blocked by an administrator.',
            ], 403);
        }

        return response()->json([
            'data' => [
                'user_id' => $user->id,
                'status'  => $user->status ?? 'Active',
                'user'    => [
                    'id'           => $user->id,
                    'user_id'      => $user->id,
                    'name'         => $user->name,
                    'phone_number' => $user->phone_number,
                    'masked_phone' => User::maskPhone($user->phone_number),
                    'user_role'    => $user->user_role ?? $user->role,
                    'status'       => $user->status ?? 'Active',
                ],
            ],
        ]);
    }

    /**
     * POST /api/v1/auth/logout
     * Invalidates the current token.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();

        return response()->json([
            'data' => ['message' => 'Logged out successfully.'],
        ]);
    }
}
