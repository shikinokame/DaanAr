<?php

namespace App\Filament\Resources;

use App\Filament\Resources\UserResource\Pages;
use App\Models\LandmarkVisit;
use App\Models\User;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Forms\Get;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static ?string $navigationIcon = 'heroicon-o-users';

    protected static ?string $navigationGroup = 'Administration';

    protected static ?int $navigationSort = 10;

    public static function canAccess(): bool
    {
        $user = Auth::user();

        return ($user?->isSuperAdmin() || $user?->isAdmin()) ?? false;
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->withCount([
                'visits as total_physical_visits' => fn (Builder $q) => $q->where('action_type', LandmarkVisit::ACTION_PHYSICAL_VISIT),
                'visits as total_ar_views' => fn (Builder $q) => $q->where('action_type', LandmarkVisit::ACTION_AR_VIEW),
            ]);
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('User Details')
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->required()
                            ->maxLength(255),
                        Forms\Components\TextInput::make('phone_number')
                            ->label('Mobile Number (+639XXXXXXXXX)')
                            ->placeholder('+639171234567')
                            ->maxLength(32)
                            ->dehydrateStateUsing(fn (?string $state): ?string => filled($state) ? User::normalizePhoneNumber($state) : null)
                            ->unique(ignoreRecord: true),
                        Forms\Components\TextInput::make('email')
                            ->email()
                            ->maxLength(255)
                            ->required(fn (Get $get): bool => in_array($get('role'), ['super_admin', 'officer', 'admin'], true))
                            ->unique(ignoreRecord: true),
                        Forms\Components\TextInput::make('password')
                            ->password()
                            ->revealable()
                            ->dehydrateStateUsing(fn (?string $state): ?string => filled($state) ? Hash::make($state) : null)
                            ->dehydrated(fn (?string $state): bool => filled($state))
                            ->required(fn (string $operation, Get $get): bool => $operation === 'create' && in_array($get('role'), ['super_admin', 'officer', 'admin'], true))
                            ->maxLength(255),
                        Forms\Components\Select::make('role')
                            ->label('Role')
                            ->options([
                                'Tourist'     => 'Tourist (Mobile)',
                                'Student'     => 'Student (Mobile)',
                                'Educator'    => 'Educator (Mobile)',
                                'officer'     => 'LGU Officer (CMS)',
                                'super_admin' => 'Super Admin (CMS)',
                            ])
                            ->required()
                            ->native(false)
                            ->live()
                            ->afterStateUpdated(function (?string $state, Forms\Set $set) {
                                if (in_array($state, ['Tourist', 'Student', 'Educator'], true)) {
                                    $set('user_role', $state);
                                }
                            }),
                        Forms\Components\Select::make('status')
                            ->label('Account Status')
                            ->options([
                                'Active'  => 'Active',
                                'Blocked' => 'Blocked',
                            ])
                            ->default('Active')
                            ->required()
                            ->native(false),
                        Forms\Components\Select::make('municipality_id')
                            ->label('Assigned Municipality')
                            ->relationship('municipality', 'name')
                            ->searchable()
                            ->preload()
                            ->visible(fn (Get $get): bool => $get('role') === 'officer')
                            ->required(fn (Get $get): bool => $get('role') === 'officer'),
                    ])
                    ->columns(2),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('phone_number')
                    ->label('Mobile Number')
                    ->searchable()
                    ->sortable()
                    ->icon('heroicon-m-device-phone-mobile')
                    ->weight('bold')
                    ->formatStateUsing(function (?string $state, User $record, $livewire): string {
                        if (! $state) {
                            return $record->email ?: '—';
                        }
                        $reveal = property_exists($livewire, 'revealPhoneNumbers') && $livewire->revealPhoneNumbers;

                        return $reveal ? $state : User::maskPhone($state);
                    })
                    ->description(fn (User $record): string => $record->name ?: ''),

                Tables\Columns\TextColumn::make('role')
                    ->label('Role')
                    ->badge()
                    ->state(fn (User $record): string => $record->user_role ?: $record->role ?: 'Tourist')
                    ->formatStateUsing(fn (string $state): string => match (strtolower($state)) {
                        'super_admin' => 'Super Admin',
                        'admin'       => 'Admin',
                        'officer'     => 'LGU Officer',
                        'tourist'     => 'Tourist',
                        'student'     => 'Student',
                        'educator'    => 'Educator',
                        default       => ucfirst($state),
                    })
                    ->color(fn (string $state): string => match (strtolower($state)) {
                        'super_admin', 'admin' => 'danger',
                        'officer'              => 'info',
                        'tourist'              => 'success',
                        'student'              => 'warning',
                        'educator'             => 'primary',
                        default                => 'gray',
                    })
                    ->sortable(),

                Tables\Columns\TextColumn::make('total_physical_visits')
                    ->label('Total Visits (On-Site)')
                    ->numeric()
                    ->sortable()
                    ->alignCenter()
                    ->color(fn (int $state): string => $state > 0 ? 'success' : 'gray')
                    ->icon('heroicon-m-map-pin')
                    ->weight('bold'),

                Tables\Columns\TextColumn::make('total_ar_views')
                    ->label('Total AR Views')
                    ->numeric()
                    ->sortable()
                    ->alignCenter()
                    ->color(fn (int $state): string => $state > 0 ? 'primary' : 'gray')
                    ->icon('heroicon-m-cube-transparent'),

                Tables\Columns\TextColumn::make('created_at')
                    ->label('Registered Date')
                    ->dateTime('M d, Y h:i A')
                    ->sortable(),

                Tables\Columns\ToggleColumn::make('status_active')
                    ->label('Status (Active)')
                    ->alignCenter()
                    ->getStateUsing(fn (User $record): bool => strtolower((string) ($record->status ?? 'Active')) !== 'blocked')
                    ->updateStateUsing(function (User $record, bool $state): bool {
                        $record->status = $state ? 'Active' : 'Blocked';
                        $record->save();
                        if (! $state) {
                            $record->tokens()->delete();
                        }

                        return $state;
                    }),

                Tables\Columns\TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->state(fn (User $record): string => $record->status ?: 'Active')
                    ->color(fn (string $state): string => strtolower($state) === 'blocked' ? 'danger' : 'success')
                    ->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Tables\Filters\SelectFilter::make('role')
                    ->label('Role')
                    ->options([
                        'Tourist'     => 'Tourist',
                        'Student'     => 'Student',
                        'Educator'    => 'Educator',
                        'officer'     => 'LGU Officer',
                        'super_admin' => 'Super Admin',
                    ]),
                Tables\Filters\SelectFilter::make('status')
                    ->options([
                        'Active'  => 'Active',
                        'Blocked' => 'Blocked',
                    ]),
            ])
            ->actions([
                Tables\Actions\Action::make('toggleStatus')
                    ->label(fn (User $record): string => strtolower((string) $record->status) === 'blocked' ? 'Activate' : 'Block')
                    ->icon(fn (User $record): string => strtolower((string) $record->status) === 'blocked' ? 'heroicon-o-check-circle' : 'heroicon-o-no-symbol')
                    ->color(fn (User $record): string => strtolower((string) $record->status) === 'blocked' ? 'success' : 'danger')
                    ->action(function (User $record): void {
                        $isBlocked = strtolower((string) $record->status) === 'blocked';
                        $record->status = $isBlocked ? 'Active' : 'Blocked';
                        $record->save();
                        if (! $isBlocked) {
                            $record->tokens()->delete();
                        }
                    }),
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ]);
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListUsers::route('/'),
            'create' => Pages\CreateUser::route('/create'),
            'edit' => Pages\EditUser::route('/{record}/edit'),
        ];
    }
}
