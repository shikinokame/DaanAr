<?php

namespace App\Services;

use RuntimeException;

class RoutingUnavailableException extends RuntimeException
{
    public function __construct(string $message, public readonly int $httpStatus)
    {
        parent::__construct($message);
    }
}
