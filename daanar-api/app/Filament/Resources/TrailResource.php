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

    /** Hidden from nav — replaced by the Reports custom page */
    public static function shouldRegisterNavigation(): bool
    {
        return false;
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
                            ->label('Municipality')
                            ->relationship('municipality', 'name')
                            ->required()
                            ->searchable()
                            ->preload()
                            ->live(),
                        Forms\Components\Select::make('difficulty')
                            ->options([
                                'easy' => 'Easy',
                                'moderate' => 'Moderate',
                                'hard' => 'Hard',
                            ])
                            ->required()
                            ->native(false),
                        Forms\Components\TextInput::make('estimated_time')
                            ->label('Estimated Time (minutes)')
                            ->required()
                            ->numeric()
                            ->minValue(1)
                            ->suffix('min'),
                        Forms\Components\Textarea::make('description')
                            ->required()
                            ->rows(4)
                            ->columnSpanFull(),
                    ])
                    ->columns(2),

                Forms\Components\Section::make('Landmarks on Trail')
                    ->description('Select landmarks and drag to set the visit order.')
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
                            ->helperText('Only landmarks from the selected municipality are shown.'),
                    ]),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('municipality.name')
                    ->label('Municipality')
                    ->sortable()
                    ->searchable(),
                Tables\Columns\TextColumn::make('difficulty')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => ucfirst($state))
                    ->color(fn (string $state): string => match ($state) {
                        'easy' => 'success',
                        'moderate' => 'warning',
                        'hard' => 'danger',
                        default => 'gray',
                    })
                    ->sortable(),
                Tables\Columns\TextColumn::make('estimated_time')
                    ->label('Duration')
                    ->formatStateUsing(fn (int $state): string => "{$state} min")
                    ->sortable(),
                Tables\Columns\TextColumn::make('landmarks_count')
                    ->counts('landmarks')
                    ->label('Landmarks'),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('difficulty')
                    ->options([
                        'easy' => 'Easy',
                        'moderate' => 'Moderate',
                        'hard' => 'Hard',
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
            'index' => Pages\ListTrails::route('/'),
            'create' => Pages\CreateTrail::route('/create'),
            'edit' => Pages\EditTrail::route('/{record}/edit'),
        ];
    }
}
