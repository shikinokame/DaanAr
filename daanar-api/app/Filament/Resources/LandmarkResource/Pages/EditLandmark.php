<?php

namespace App\Filament\Resources\LandmarkResource\Pages;

use App\Filament\Resources\LandmarkResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\Auth;

class EditLandmark extends EditRecord
{
    protected static string $resource = LandmarkResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }

    protected function mutateFormDataBeforeSave(array $data): array
    {
        $user = Auth::user();

        if ($user?->isLguEditor() && $user->municipality_id) {
            $data['municipality_id'] = $user->municipality_id;
        }

        return $data;
    }
}
