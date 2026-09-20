<?php

namespace Database\Seeders;

use App\Models\Landmark;
use App\Models\Municipality;
use App\Models\User;
use Illuminate\Database\Seeder;

class DaanArSeeder extends Seeder
{
    public function run(): void
    {
        $municipalities = collect([
            [
                'name' => 'Dagupan City',
                'province' => 'Pangasinan',
                'lat' => 16.04300000,
                'lng' => 120.33330000,
                'description' => 'Known as the Bangus Capital of the Philippines, Dagupan is a major commercial hub in Pangasinan with rich culinary and cultural heritage.',
            ],
            [
                'name' => 'Manaoag',
                'province' => 'Pangasinan',
                'lat' => 16.04390000,
                'lng' => 120.48560000,
                'description' => 'Home to the nationally renowned Our Lady of Manaoag Shrine, a major pilgrimage destination in Northern Luzon.',
            ],
            [
                'name' => 'Mangaldan',
                'province' => 'Pangasinan',
                'lat' => 16.07000000,
                'lng' => 120.40280000,
                'description' => 'One of the oldest towns in Pangasinan, known for its Spanish-era church and vibrant local traditions.',
            ],
            [
                'name' => 'San Fabian',
                'province' => 'Pangasinan',
                'lat' => 16.15000000,
                'lng' => 120.41670000,
                'description' => 'A coastal municipality famous for its long sandy beaches along Lingayen Gulf.',
            ],
            [
                'name' => 'San Jacinto',
                'province' => 'Pangasinan',
                'lat' => 16.06670000,
                'lng' => 120.43330000,
                'description' => 'A historic town in eastern Pangasinan with well-preserved heritage structures and community plazas.',
            ],
        ])->mapWithKeys(function (array $data) {
            $municipality = Municipality::create($data);

            return [$municipality->name => $municipality];
        });

        User::create([
            'name' => 'DaanAR Super Admin',
            'email' => 'admin@daanar.ph',
            'password' => 'password',
            'role' => 'super_admin',
            'municipality_id' => null,
        ]);

        $landmarks = [
            [
                'municipality' => 'Dagupan City',
                'name' => 'Dagupan City Plaza',
                'description' => 'The central public plaza of Dagupan City, surrounded by heritage buildings and a gathering place for festivals and civic events since the American colonial period.',
                'short_description' => 'Historic city plaza at the heart of Dagupan.',
                'category' => 'park',
                'era' => 'American Colonial',
                'address' => 'Perez Blvd, Dagupan City, Pangasinan',
                'lat' => 16.04380000,
                'lng' => 120.33450000,
                'is_featured' => true,
            ],
            [
                'municipality' => 'Dagupan City',
                'name' => 'St. John the Evangelist Cathedral',
                'description' => 'The cathedral parish of Dagupan, rebuilt after World War II and serving as a spiritual and architectural landmark in the city center.',
                'short_description' => 'Main cathedral parish of Dagupan City.',
                'category' => 'church',
                'era' => 'Post-War',
                'address' => 'Perez Blvd, Dagupan City, Pangasinan',
                'lat' => 16.04320000,
                'lng' => 120.33380000,
                'is_featured' => true,
            ],
            [
                'municipality' => 'Dagupan City',
                'name' => 'Bonuan Blue Beach',
                'description' => 'A popular coastal area in Dagupan along Lingayen Gulf, known for its wide shoreline and local seafood culture tied to the city\'s bangus industry.',
                'short_description' => 'Coastal beach area along Lingayen Gulf.',
                'category' => 'natural',
                'era' => null,
                'address' => 'Bonuan Gueset, Dagupan City, Pangasinan',
                'lat' => 16.06050000,
                'lng' => 120.35800000,
                'is_featured' => false,
            ],
            [
                'municipality' => 'Manaoag',
                'name' => 'Our Lady of Manaoag Shrine',
                'description' => 'A major Roman Catholic pilgrimage site dedicated to Our Lady of the Rosary of Manaoag, attracting devotees from across the Philippines.',
                'short_description' => 'National pilgrimage shrine of Our Lady of Manaoag.',
                'category' => 'church',
                'era' => 'Spanish Colonial',
                'address' => 'Manaoag, Pangasinan',
                'lat' => 16.04420000,
                'lng' => 120.48610000,
                'is_featured' => true,
            ],
            [
                'municipality' => 'Manaoag',
                'name' => 'Manaoag Town Plaza',
                'description' => 'The municipal plaza of Manaoag, located near the shrine complex and serving as a venue for religious processions and town festivities.',
                'short_description' => 'Municipal plaza near the Manaoag Shrine.',
                'category' => 'park',
                'era' => 'Spanish Colonial',
                'address' => 'Poblacion, Manaoag, Pangasinan',
                'lat' => 16.04350000,
                'lng' => 120.48480000,
                'is_featured' => false,
            ],
            [
                'municipality' => 'Mangaldan',
                'name' => 'St. Thomas Aquinas Parish Church',
                'description' => 'A historic church in Mangaldan founded during the Spanish era, featuring stone construction and serving as a focal point of town heritage.',
                'short_description' => 'Spanish-era parish church of Mangaldan.',
                'category' => 'church',
                'era' => 'Spanish Colonial',
                'address' => 'Poblacion, Mangaldan, Pangasinan',
                'lat' => 16.06950000,
                'lng' => 120.40220000,
                'is_featured' => true,
            ],
            [
                'municipality' => 'Mangaldan',
                'name' => 'Mangaldan Heritage House',
                'description' => 'A preserved ancestral house showcasing traditional Pangasinan architecture and local family history from the early 20th century.',
                'short_description' => 'Preserved ancestral house with local heritage exhibits.',
                'category' => 'historical',
                'era' => 'Early 20th Century',
                'address' => 'Rizal St, Mangaldan, Pangasinan',
                'lat' => 16.07030000,
                'lng' => 120.40350000,
                'is_featured' => false,
            ],
            [
                'municipality' => 'San Fabian',
                'name' => 'San Fabian Beach',
                'description' => 'A well-known stretch of Lingayen Gulf shoreline in San Fabian, popular for swimming, picnics, and viewing sunsets along the coast.',
                'short_description' => 'Popular public beach on Lingayen Gulf.',
                'category' => 'natural',
                'era' => null,
                'address' => 'San Fabian, Pangasinan',
                'lat' => 16.15200000,
                'lng' => 120.41800000,
                'is_featured' => true,
            ],
            [
                'municipality' => 'San Fabian',
                'name' => 'St. Fabian Parish Church',
                'description' => 'The parish church of San Fabian, a longstanding religious landmark that anchors the town\'s cultural and community life.',
                'short_description' => 'Parish church of San Fabian municipality.',
                'category' => 'church',
                'era' => 'Spanish Colonial',
                'address' => 'Poblacion, San Fabian, Pangasinan',
                'lat' => 16.14980000,
                'lng' => 120.41620000,
                'is_featured' => false,
            ],
            [
                'municipality' => 'San Jacinto',
                'name' => 'San Jacinto Municipal Hall',
                'description' => 'The seat of local government in San Jacinto, housed in a building that reflects the town\'s administrative history and civic identity.',
                'short_description' => 'Historic municipal government building.',
                'category' => 'historical',
                'era' => 'American Colonial',
                'address' => 'Poblacion, San Jacinto, Pangasinan',
                'lat' => 16.06690000,
                'lng' => 120.43280000,
                'is_featured' => false,
            ],
        ];

        foreach ($landmarks as $landmark) {
            $municipalityName = $landmark['municipality'];
            unset($landmark['municipality']);

            Landmark::create([
                ...$landmark,
                'municipality_id' => $municipalities[$municipalityName]->id,
            ]);
        }
    }
}
