<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Resources\UserResource;
use Filament\Actions;
use Filament\Resources\Components\Tab;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

class ListUsers extends ListRecords
{
    protected static string $resource = UserResource::class;

    public bool $revealPhoneNumbers = false;

    protected function getHeaderActions(): array
    {
        return [
            Actions\Action::make('togglePhones')
                ->label(fn (): string => $this->revealPhoneNumbers ? 'Mask Mobile Numbers' : 'Show Full Mobile Numbers')
                ->icon(fn (): string => $this->revealPhoneNumbers ? 'heroicon-o-eye-slash' : 'heroicon-o-eye')
                ->color('gray')
                ->visible(fn (): bool => Auth::user()?->isSuperAdmin() ?? false)
                ->action(function (): void {
                    $this->revealPhoneNumbers = ! $this->revealPhoneNumbers;
                }),
            Actions\CreateAction::make(),
        ];
    }

    public function getTabs(): array
    {
        return [
            'all' => Tab::make('All Users'),
            'mobile' => Tab::make('Mobile App Visitors')
                ->modifyQueryUsing(fn (Builder $query) => $query->whereNotNull('phone_number')),
            'staff' => Tab::make('Admin & LGU Staff')
                ->modifyQueryUsing(fn (Builder $query) => $query->whereIn('role', ['super_admin', 'admin', 'officer'])),
        ];
    }
}
