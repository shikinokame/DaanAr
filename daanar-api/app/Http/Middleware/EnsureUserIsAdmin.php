<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsAdmin
{
    /**
     * Registered as 'admin' in bootstrap/app.php's ->withMiddleware() alias list.
     * Both 'officer' and 'admin' roles may manage landmarks; only 'admin' can
     * additionally manage other user accounts (enforced separately if you add that screen).
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->user() || ! in_array($request->user()->role, ['officer', 'admin'], true)) {
            abort(403, 'You do not have access to the admin panel.');
        }

        return $next($request);
    }
}
