<?php

namespace App\Filament\Resources;

use App\Filament\Resources\TrailResource\Pages;
use App\Models\Trail;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Forms\Get;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class TrailResource extends Resource
{
    protected static ?string $model = Trail::class;

    protected static ?string $navigationIcon = 'heroicon-o-map';

    protected static ?string $navigationGroup = 'Heritage Management';

    protected static ?int $navigationSort = 3;

    public static function shouldRegisterNavigation(): bool
    {
        return true;
    }

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Trail Details')
                    ->schema([
                        Forms\Components\TextInput::make('name')
                            ->required()
                            ->maxLength(255),
                        Forms\Components\Select::make('municipality_id')
                            ->label('Municipality (leave blank for multi-town trail)')
                            ->relationship('municipality', 'name')
                            ->nullable()
                            ->placeholder('Multi-Municipality / District Trail')
                            ->searchable()
                            ->preload()
                            ->live(),
                        Forms\Components\TextInput::make('district')
                            ->label('District / Coverage Label')
                            ->placeholder('e.g. District 4')
                            ->maxLength(64),
                        Forms\Components\Select::make('difficulty')
                            ->options([
                                'easy'     => 'Easy',
                                'moderate' => 'Moderate',
                                'hard'     => 'Hard',
                            ])
                            ->required()
                            ->native(false),
                        Forms\Components\TextInput::make('estimated_time')
                            ->label('Estimated Time (minutes)')
                            ->required()
                            ->numeric()
                            ->minValue(1)
                            ->suffix('min'),
                        Forms\Components\TextInput::make('total_distance_metres')
                            ->label('Total Distance (metres)')
                            ->numeric()
                            ->minValue(0)
                            ->suffix('m'),
                        Forms\Components\Textarea::make('description')
                            ->required()
                            ->rows(4)
                            ->columnSpanFull(),
                    ])
                    ->columns(2),

                Forms\Components\Section::make('Landmarks on Trail')
                    ->description('Select landmarks across one or more municipalities and drag to set the visit order.')
                    ->schema([
                        Forms\Components\Select::make('landmarks')
                            ->relationship(
                                name: 'landmarks',
                                titleAttribute: 'name',
                                modifyQueryUsing: fn (Builder $query, Get $get) => $query->when(
                                    $get('municipality_id'),
                                    fn (Builder $query, int $municipalityId) => $query->where('municipality_id', $municipalityId),
                                ),
                            )
                            ->multiple()
                            ->searchable()
                            ->preload()
                            ->reorderable()
                            ->orderColumn('order')
                            ->columnSpanFull()
                            ->helperText('Leave Municipality blank above to combine landmarks from multiple towns (e.g. District 4 Heritage Trail).'),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),
                Tables\Columns\TextColumn::make('municipality.name')
                    ->label('Coverage')
                    ->default(fn (Trail $record): string => $record->district ?: 'Multi-Municipality')
                    ->sortable()
                    ->searchable(),
                Tables\Columns\TextColumn::make('difficulty')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => ucfirst($state))
                    ->color(fn (string $state): string => match ($state) {
                        'easy'     => 'success',
                        'moderate' => 'warning',
                        'hard'     => 'danger',
                        default    => 'gray',
                    })
                    ->sortable(),
                Tables\Columns\TextColumn::make('estimated_time')
                    ->label('Duration')
                    ->formatStateUsing(fn (int $state): string => "{$state} min")
                    ->sortable(),
                Tables\Columns\TextColumn::make('total_distance_metres')
                    ->label('Distance')
                    ->formatStateUsing(fn (?int $state): string => $state ? number_format($state / 1000, 1) . ' km' : '—')
                    ->sortable(),
                Tables\Columns\TextColumn::make('landmarks_count')
                    ->counts('landmarks')
                    ->label('Stops'),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('difficulty')
                    ->options([
                        'easy'     => 'Easy',
                        'moderate' => 'Moderate',
                        'hard'     => 'Hard',
                    ]),
                Tables\Filters\SelectFilter::make('municipality_id')
                    ->label('Municipality')
                    ->relationship('municipality', 'name'),
            ])
            ->actions([
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
            'index'  => Pages\ListTrails::route('/'),
            'create' => Pages\CreateTrail::route('/create'),
            'edit'   => Pages\EditTrail::route('/{record}/edit'),
        ];
    }
}
