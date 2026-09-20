<?php

namespace App\Filament\Resources\TrailResource\Pages;

use App\Filament\Resources\TrailResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListTrails extends ListRecords
{
    protected static string $resource = TrailResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
