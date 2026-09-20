<?php

namespace App\Filament\Widgets;

use App\Filament\Resources\LandmarkResource;
use App\Models\Landmark;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use Illuminate\Support\Facades\Auth;

class RecentLandmarksWidget extends BaseWidget
{
    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    protected static ?string $heading = 'Recently Added Landmarks';

    public function table(Table $table): Table
    {
        $user = Auth::user();

        return $table
            ->query(function () use ($user) {
                $query = Landmark::query()
                    ->with('municipality')
                    ->latest();

                if ($user?->isLguEditor() && $user->municipality_id) {
                    $query->where('municipality_id', $user->municipality_id);
                }

                return $query->limit(5);
            })
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->searchable(),
                Tables\Columns\TextColumn::make('municipality.name')
                    ->label('Municipality'),
                Tables\Columns\TextColumn::make('category')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => ucfirst($state)),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('Added')
                    ->since(),
            ])
            ->actions([
                Tables\Actions\Action::make('edit')
                    ->label('Edit')
                    ->icon('heroicon-m-pencil-square')
                    ->url(fn (Landmark $record): string => LandmarkResource::getUrl('edit', ['record' => $record])),
            ])
            ->paginated(false);
    }
}
