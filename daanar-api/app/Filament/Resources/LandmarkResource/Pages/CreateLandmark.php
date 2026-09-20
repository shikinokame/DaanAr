<?php

namespace App\Filament\Resources\LandmarkResource\Pages;

use App\Filament\Resources\LandmarkResource;
use Filament\Resources\Pages\CreateRecord;
use Illuminate\Support\Facades\Auth;

class CreateLandmark extends CreateRecord
{
    protected static string $resource = LandmarkResource::class;

    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $user = Auth::user();

        if ($user?->isLguEditor() && $user->municipality_id) {
            $data['municipality_id'] = $user->municipality_id;
        }

        return $data;
    }
}
