<?php

namespace App\Filament\Resources;

use App\Filament\Resources\LandmarkResource\Pages;
use App\Models\Landmark;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Auth;

class LandmarkResource extends Resource
{
    protected static ?string $model = Landmark::class;

    protected static ?string $navigationIcon = 'heroicon-o-building-library';

    protected static ?string $navigationGroup = 'Heritage Management';

    protected static ?int $navigationSort = 2;

    public static function form(Form $form): Form
    {
        $user = Auth::user();

        return $form
            ->schema([
                Forms\Components\Section::make('Basic Information')
                    ->schema([
                        Forms\Components\Select::make('municipality_id')
                            ->label('Municipality')
                            ->relationship(
                                name: 'municipality',
                                titleAttribute: 'name',
                                modifyQueryUsing: fn (Builder $query) => static::scopeMunicipalityOptions($query),
                            )
                            ->required()
                            ->searchable()
                            ->preload()
                            ->default($user?->isLguEditor() ? $user->municipality_id : null)
                            ->disabled($user?->isLguEditor() ?? false),
                        Forms\Components\TextInput::make('name')
                            ->required()
                            ->maxLength(255),
                        Forms\Components\Select::make('category')
                            ->options([
                                'church' => 'Church',
                                'park' => 'Park',
                                'historical' => 'Historical',
                                'natural' => 'Natural',
                                'cultural' => 'Cultural',
                            ])
                            ->required()
                            ->native(false),
                        Forms\Components\TextInput::make('era')
                            ->maxLength(255),
                        Forms\Components\TextInput::make('address')
                            ->required()
                            ->maxLength(255)
                            ->columnSpanFull(),
                        Forms\Components\Textarea::make('short_description')
                            ->required()
                            ->rows(2)
                            ->columnSpanFull(),
                        Forms\Components\Textarea::make('description')
                            ->required()
                            ->rows(5)
                            ->columnSpanFull(),
                    ])
                    ->columns(2),

                Forms\Components\Section::make('Location')
                    ->schema([
                        Forms\Components\TextInput::make('lat')
                            ->label('Latitude')
                            ->required()
                            ->numeric()
                            ->step(0.00000001),
                        Forms\Components\TextInput::make('lng')
                            ->label('Longitude')
                            ->required()
                            ->numeric()
                            ->step(0.00000001),
                    ])
                    ->columns(2),

                Forms\Components\Section::make('Media & AR Assets')
                    ->schema([
                        Forms\Components\FileUpload::make('hero_image')
                            ->label('Hero Image')
                            ->image()
                            ->disk('public')
                            ->directory('landmarks/hero')
                            ->maxSize(307200)
                            ->imageEditor(),
                        Forms\Components\FileUpload::make('ar_marker_image')
                            ->label('AR Marker Image')
                            ->image()
                            ->disk('public')
                            ->directory('landmarks/markers')
                            ->maxSize(307200),
                        Forms\Components\FileUpload::make('ar_model_url')
                            ->label('AR 3D Model')
                            ->disk('public')
                            ->directory('landmarks/models')
                            ->acceptedFileTypes([
                                'model/gltf+json',
                                'model/gltf-binary',
                                'application/octet-stream',
                            ])
                            ->maxSize(307200),
                        Forms\Components\TextInput::make('ar_html_path')
                            ->label('AR HTML Path')
                            ->maxLength(255)
                            ->placeholder('/ar/landmark/{id}'),
                        Forms\Components\Toggle::make('is_featured')
                            ->label('Featured Landmark')
                            ->default(false),
                    ])
                    ->columns(2),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\ImageColumn::make('hero_image')
                    ->disk('public')
                    ->circular(),
                Tables\Columns\TextColumn::make('name')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('municipality.name')
                    ->label('Municipality')
                    ->sortable()
                    ->searchable(),
                Tables\Columns\TextColumn::make('category')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => ucfirst($state))
                    ->sortable(),
                Tables\Columns\IconColumn::make('is_featured')
                    ->boolean()
                    ->sortable(),
                Tables\Columns\TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('category')
                    ->options([
                        'church' => 'Church',
                        'park' => 'Park',
                        'historical' => 'Historical',
                        'natural' => 'Natural',
                        'cultural' => 'Cultural',
                    ]),
                Tables\Filters\SelectFilter::make('municipality_id')
                    ->label('Municipality')
                    ->relationship(
                        name: 'municipality',
                        titleAttribute: 'name',
                        modifyQueryUsing: fn (Builder $query) => static::scopeMunicipalityOptions($query),
                    )
                    ->visible(fn (): bool => Auth::user()?->isSuperAdmin() ?? false),
                Tables\Filters\TernaryFilter::make('is_featured')
                    ->label('Featured'),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getEloquentQuery(): Builder
    {
        $query = parent::getEloquentQuery();
        $user = Auth::user();

        if ($user?->isLguEditor() && $user->municipality_id) {
            $query->where('municipality_id', $user->municipality_id);
        }

        return $query;
    }

    public static function getRelations(): array
    {
        return [];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListLandmarks::route('/'),
            'create' => Pages\CreateLandmark::route('/create'),
            'edit' => Pages\EditLandmark::route('/{record}/edit'),
        ];
    }

    protected static function scopeMunicipalityOptions(Builder $query): Builder
    {
        $user = Auth::user();

        if ($user?->isLguEditor() && $user->municipality_id) {
            $query->whereKey($user->municipality_id);
        }

        return $query;
    }
}
