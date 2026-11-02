<?php

namespace Database\Seeders;

use App\Models\Landmark;
use App\Models\Municipality;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

class DaanArSeeder extends Seeder
{
    public function run(): void
    {
        $municipalitiesData = [
            [
                'name' => 'Dagupan City',
                'province' => 'Pangasinan',
                'lat' => 16.04300000,
                'lng' => 120.33330000,
                'description' => 'Known as the Bangus Capital of the Philippines, Dagupan is a major commercial and historical hub in Pangasinan with rich colonial, culinary, and transport heritage.',
            ],
            [
                'name' => 'Manaoag',
                'province' => 'Pangasinan',
                'lat' => 16.04390000,
                'lng' => 120.48560000,
                'description' => 'Home to the nationally renowned Minor Basilica of Our Lady of the Rosary of Manaoag, one of the premier pilgrimage and religious heritage destinations in Southeast Asia.',
            ],
            [
                'name' => 'Mangaldan',
                'province' => 'Pangasinan',
                'lat' => 16.07000000,
                'lng' => 120.40280000,
                'description' => 'One of the oldest towns in Pangasinan, founded in 1600, celebrated for its Dominican-era parish church and rich livestock and commerce history.',
            ],
            [
                'name' => 'San Jacinto',
                'province' => 'Pangasinan',
                'lat' => 16.06670000,
                'lng' => 120.43330000,
                'description' => 'A historic municipality founded in 1598, prominent for its Dominican church heritage and the historic 1899 Battle of San Jacinto battlefield.',
            ],
            [
                'name' => 'San Fabian',
                'province' => 'Pangasinan',
                'lat' => 16.15000000,
                'lng' => 120.41670000,
                'description' => 'A coastal town along Lingayen Gulf founded in 1717, rich in maritime history, Spanish colonial architecture, and northern railroad junction heritage.',
            ],
        ];

        $municipalities = collect();
        foreach ($municipalitiesData as $data) {
            $m = Municipality::updateOrCreate(
                ['name' => $data['name']],
                $data
            );
            $municipalities->put($m->name, $m);
        }

        // Use firstOrCreate NOT updateOrCreate so the password is hashed ONCE.
        // updateOrCreate re-hashes on every `db:seed --force`, breaking login.
        User::firstOrCreate(
            ['email' => 'admin@daanar.ph'],
            [
                'name' => 'DaanAR Super Admin',
                'password' => 'Vinosaurs',
                'role' => 'super_admin',
                'municipality_id' => null,
            ]
        );

        $landmarks = [
            // Dagupan City
            [
                'municipality' => 'Dagupan City',
                'name' => 'Old PNR Dagupan/Mayombo (1st) Station',
                'description' => 'The Old PNR Dagupan Station in Mayombo was the historic first northern terminus of the Ferrocaril de Manila a Dagupan, officially inaugurated on November 24, 1892. Built during the late Spanish colonial period, it served as a vital commercial artery connecting Northern Luzon to Manila and played a crucial logistical role during the Philippine Revolution and Philippine-American War.',
                'short_description' => 'Historic 1892 northern terminus of the Manila-Dagupan railway.',
                'category' => 'historical',
                'era' => 'Spanish Colonial',
                'address' => '28WW+827, Mayombo District, Dagupan City, Pangasinan',
                'lat' => 16.04581200,
                'lng' => 120.34506300,
                'hero_image' => 'landmarks/hero/01M3SBX8Q4B1STH98NTQ9XB2S2.jpg',
                'ar_model_url' => 'landmarks/models/01M3V1DR3QRRHX25THD630R5G1.glb',
                'is_featured' => false,
            ],
            [
                'municipality' => 'Dagupan City',
                'name' => 'Santuario de San Juan Evangelista',
                'description' => 'The Santuario de San Juan Evangelista (Metropolitan Cathedral of Saint John the Evangelist) was originally established by Augustinian and Dominican friars in the late 16th century. Reconstructed following major earthquakes and World War II bombings, it stands as the spiritual seat of the Archdiocese of Lingayen-Dagupan with Spanish colonial sacred art, ornate altars, and an iconic belfry.',
                'short_description' => 'Historic mother parish and cathedral of Dagupan City.',
                'category' => 'church',
                'era' => 'Spanish Colonial',
                'address' => 'Zamora St, Downtown District, Dagupan City, Pangasinan',
                'lat' => 16.04320000,
                'lng' => 120.33380000,
                'hero_image' => 'landmarks/hero/01M3TPZD7RTHQ7WVD5YQAE8BAV.jpg',
                'ar_model_url' => 'landmarks/models/01M3V95CJWDJ047YT8SGA7HX4A.glb',
                'is_featured' => true,
            ],

            // Manaoag
            [
                'municipality' => 'Manaoag',
                'name' => 'Minor Basilica of Our Lady of the Rosary of Manaoag',
                'description' => 'One of the most revered Roman Catholic pilgrimage sites in Southeast Asia, the Minor Basilica of Our Lady of the Rosary of Manaoag was administered by the Dominican Order starting in 1605. The ivory image of the Virgin Mary, brought from Spain via Mexico in the 17th century, is venerated by millions of pilgrims annually for reported miraculous intercessions.',
                'short_description' => 'Renowned national pilgrimage basilica founded in the 1600s.',
                'category' => 'church',
                'era' => 'Spanish Colonial',
                'address' => 'Milo St, Poblacion, Manaoag, Pangasinan',
                'lat' => 16.04420000,
                'lng' => 120.48610000,
                'hero_image' => 'landmarks/hero/01M3TQRD2ECX7XTJXP638W8X37.png',
                'ar_model_url' => 'landmarks/models/01M3W1QQVGZRDS724GGNRDNA1G.glb',
                'is_featured' => true,
            ],
            [
                'municipality' => 'Manaoag',
                'name' => 'Old PNR Manaoag (Binday) Station',
                'description' => 'The Old PNR Manaoag (Binday) branch line was constructed by the Manila Railroad Company in the early 1900s as a dedicated railway spur to transport the large influx of pilgrims and agricultural goods between San Fabian and Manaoag. The line revolutionized religious pilgrimage in Pangasinan before 20th-century highway expansions replaced regional rail transport.',
                'short_description' => 'Historic railway pilgrim branch built in 1908 for Manaoag devotees.',
                'category' => 'historical',
                'era' => 'American Colonial',
                'address' => 'Binday-Manaoag Access Road, Manaoag, Pangasinan',
                'lat' => 16.07120000,
                'lng' => 120.46850000,
                'hero_image' => null,
                'ar_model_url' => null,
                'is_featured' => false,
            ],
            [
                'municipality' => 'Manaoag',
                'name' => 'Historic Town Plaza and Street Grid',
                'description' => 'Centered around the Minor Basilica of Our Lady of the Rosary, the Historic Town Plaza and Street Grid forms the civic and religious center of Manaoag, Pangasinan. The radial street layout extends from the central church square to support pilgrimage processions, preserving its early Spanish urban plan.',
                'short_description' => 'The physical layout and historical heart of Manaoag, established during the Spanish colonial period and evolving through the Philippine-American War era.',
                'category' => 'park',
                'era' => 'Philippine-American War',
                'address' => 'Poblacion, Manaoag, Pangasinan 2430',
                'lat' => 16.04390000,
                'lng' => 120.48610000,
                'hero_image' => 'landmarks/hero/01M3V0WDNJ8KKVPCAW731CW1GK.png',
                'ar_model_url' => null,
                'is_featured' => false,
            ],

            // Mangaldan
            [
                'municipality' => 'Mangaldan',
                'name' => 'Saint Thomas Aquinas Parish Church',
                'description' => 'Founded in 1600 by the Dominican Order, the Parish Church of Saint Thomas Aquinas in Mangaldan stands as one of Pangasinan’s oldest ecclesiastical communities. Having survived multiple major earthquakes and rebuilt across epochs, the church features massive masonry walls and anchors the town’s rich cultural and spiritual traditions.',
                'short_description' => 'Centuries-old Dominican parish church dedicated to St. Thomas Aquinas.',
                'category' => 'church',
                'era' => 'Spanish Colonial',
                'address' => '3CC5+J26, Rizal Ave, Poblacion, Mangaldan, 2432 Pangasinan',
                'lat' => 16.07156200,
                'lng' => 120.40756200,
                'hero_image' => 'landmarks/hero/01M3TRZ9GQYDDSBFJW7JK8QKD0.png',
                'ar_model_url' => 'landmarks/models/01M3W5A4N3MS5H46YRNDJBR324.glb',
                'is_featured' => true,
            ],
            [
                'municipality' => 'Mangaldan',
                'name' => 'PNR Mangaldan Station',
                'description' => 'The PNR Mangaldan Station was a key stop on the Manila Railroad Company’s northern line extension from Dagupan toward San Fabian and La Union. During the early 20th century, the station supported Mangaldan’s agricultural trade, especially carabao livestock and processed meat products.',
                'short_description' => 'Historic railroad station on the Northern Luzon line extension.',
                'category' => 'historical',
                'era' => 'American Colonial',
                'address' => '3CG2+W3, Poblacion, Mangaldan, Pangasinan',
                'lat' => 16.07731300,
                'lng' => 120.40018800,
                'hero_image' => 'landmarks/hero/01M3TS45VJZ32Y3KMF6DJGWFSG.png',
                'ar_model_url' => 'landmarks/models/01M3W89Y2WAQSZJMPZEFEQSCZB.glb',
                'is_featured' => false,
            ],

            // San Jacinto
            [
                'municipality' => 'San Jacinto',
                'name' => 'Battle of San Jacinto Monument',
                'description' => 'The Battle of San Jacinto took place on November 11, 1899, during the Philippine-American War. Filipino revolutionary forces under General Manuel Tinio fought fiercely to delay advancing American troops under General Arthur MacArthur and Brigadier General Loyd Wheaton, enabling General Emilio Aguinaldo’s government to safely evacuate northward into the Cordilleras.',
                'short_description' => 'Historical battle site of the Philippine-American War on Nov 11, 1899.',
                'category' => 'historical',
                'era' => 'Philippine-American War',
                'address' => 'National Highway, San Jacinto, Pangasinan (16.09256° N, 120.43202° E)',
                'lat' => 16.09256000,
                'lng' => 120.43202000,
                'hero_image' => 'landmarks/hero/01M3R00X28C18MFY5BBSNKAJQ6.jpg',
                'ar_model_url' => 'landmarks/models/01M3R00X2DQCWJJNBWB6KKT984.glb',
                'is_featured' => false,
            ],
            [
                'municipality' => 'San Jacinto',
                'name' => 'St. Hyacinth Parish Church – San Jacinto',
                'description' => 'St. Hyacinth Parish Church is among the oldest parishes in Pangasinan, founded as a Dominican mission on August 17, 1598. Dedicated to Saint Hyacinth of Poland, the church was reconstructed multiple times after major earthquakes, retaining antique statues, Spanish-era liturgical heritage, and classic colonial Philippine church architecture.',
                'short_description' => 'One of Pangasinan’s earliest Dominican missions, founded in 1598.',
                'category' => 'church',
                'era' => 'Spanish Colonial',
                'address' => '3CFP+FW8, Poblacion, San Jacinto, Pangasinan',
                'lat' => 16.07368700,
                'lng' => 120.43731300,
                'hero_image' => 'landmarks/hero/01M3TTBAVN6N2QMN953AD5YBT3.png',
                'ar_model_url' => 'landmarks/models/01M3VY05M15WQGJVXYFV07Z1RW.glb',
                'is_featured' => true,
            ],

            // San Fabian
            [
                'municipality' => 'San Fabian',
                'name' => 'Parish of St. Fabian, Pope and Martyr',
                'description' => 'Established by Dominican missionaries in 1717, the San Fabian Parish Church is dedicated to Pope Saint Fabian. Situated close to the historic shores of Lingayen Gulf, the church played an active role during both the Spanish and American colonial eras as a cultural anchor and safe haven during coastal invasions and typhoons.',
                'short_description' => 'Historic 1717 parish church overlooking the Lingayen Gulf coast.',
                'category' => 'church',
                'era' => 'Spanish Colonial',
                'address' => '49CX+WVJ, Nibaliw Center / Braganza St, Poblacion, San Fabian, 2433 Pangasinan',
                'lat' => 16.12231200,
                'lng' => 120.39968800,
                'hero_image' => 'landmarks/hero/01M3TVXBPQG4E2CHJWB4N32QP3.png',
                'ar_model_url' => 'landmarks/models/01M3WF2YSJCQCDZMSVAKBGBQJY.glb',
                'is_featured' => true,
            ],
            [
                'municipality' => 'San Fabian',
                'name' => 'Old PNR San Fabian Station',
                'description' => 'The Old PNR San Fabian Station served as a vital railroad hub in northern Pangasinan, acting as the junction point where the mainline to San Fernando, La Union met the ambitious Camp One mountain railway branch built toward Kennon Road to connect Baguio. Its surviving infrastructure stands as a monument to early 20th-century Philippine transport history.',
                'short_description' => 'Historic junction station connecting the mainline to the Camp One Baguio spur.',
                'category' => 'historical',
                'era' => 'American Colonial',
                'address' => '4CC4+99H, Poblacion, San Fabian, Pangasinan',
                'lat' => 16.12093700,
                'lng' => 120.40593700,
                'hero_image' => 'landmarks/hero/01M3TW6RJ83KPEJRB31Z6GB5VV.png',
                'ar_model_url' => 'landmarks/models/01M3WGHD4YFVX2EHF8ZX5WXY0M.glb',
                'is_featured' => false,
            ],
        ];

        // Safely update or create landmarks without wiping existing entries
        $landmarkModels = collect();
        foreach ($landmarks as $landmark) {
            $municipalityName = $landmark['municipality'];
            unset($landmark['municipality']);

            $lm = Landmark::firstOrNew(['name' => $landmark['name']]);

            // Media files (3D models / hero images) are managed by admins in the
            // Filament panel. This seeder runs on EVERY deploy (`db:seed --force`),
            // so never overwrite media on an existing landmark otherwise each
            // redeploy reverts admin uploads back to the seeded file paths.
            if ($lm->exists) {
                foreach (['ar_model_url', 'hero_image'] as $mediaField) {
                    if (!empty($lm->{$mediaField})) {
                        unset($landmark[$mediaField]);
                    }
                }
            }

            $lm->fill([
                ...$landmark,
                'municipality_id' => $municipalities[$municipalityName]->id,
            ])->save();
            $landmarkModels->put($lm->name, $lm);
        }

        // Seed District 4 Heritage Trail + Town Sub-Trails
        $trailsData = [
            [
                'name'           => 'District 4 Heritage Trail',
                'municipality'   => null,
                'district'       => 'District 4 (Dagupan • Mangaldan • San Jacinto • San Fabian)',
                'difficulty'     => 'moderate',
                'estimated_time' => 95,
                'description'    => 'Multi-town heritage route across Pangasinan’s 4th District starting from Dagupan City’s Spanish-era cathedral and 1892 railway station, passing through Mangaldan and San Jacinto’s historic parishes and 1899 battlefield, and ending at the coastal landmarks of San Fabian.',
                'stops'          => [
                    'Santuario de San Juan Evangelista',
                    'Old PNR Dagupan/Mayombo (1st) Station',
                    'Saint Thomas Aquinas Parish Church',
                    'PNR Mangaldan Station',
                    'St. Hyacinth Parish Church – San Jacinto',
                    'Battle of San Jacinto Monument',
                    'Parish of St. Fabian, Pope and Martyr',
                    'Old PNR San Fabian Station',
                ],
            ],
            [
                'name'           => 'Dagupan City Colonial & Railway Walk',
                'municipality'   => 'Dagupan City',
                'district'       => 'District 4',
                'difficulty'     => 'easy',
                'estimated_time' => 25,
                'description'    => 'Explore Downtown Dagupan’s spiritual seat at the Santuario de San Juan Evangelista and trace the historic 1892 Ferrocarril de Manila-Dagupan terminus in Mayombo.',
                'stops'          => [
                    'Santuario de San Juan Evangelista',
                    'Old PNR Dagupan/Mayombo (1st) Station',
                ],
            ],
            [
                'name'           => 'Mangaldan Dominican & Rail Trail',
                'municipality'   => 'Mangaldan',
                'district'       => 'District 4',
                'difficulty'     => 'easy',
                'estimated_time' => 20,
                'description'    => 'A walking heritage route connecting Mangaldan’s 1600 Dominican parish church of Saint Thomas Aquinas with the American-era PNR Mangaldan Station.',
                'stops'          => [
                    'Saint Thomas Aquinas Parish Church',
                    'PNR Mangaldan Station',
                ],
            ],
            [
                'name'           => 'San Jacinto 1598 Mission & Battlefield Trail',
                'municipality'   => 'San Jacinto',
                'district'       => 'District 4',
                'difficulty'     => 'easy',
                'estimated_time' => 30,
                'description'    => 'Journey from the 1598 Dominican mission of St. Hyacinth Parish Church to the historic site of the November 1899 Battle of San Jacinto.',
                'stops'          => [
                    'St. Hyacinth Parish Church – San Jacinto',
                    'Battle of San Jacinto Monument',
                ],
            ],
            [
                'name'           => 'San Fabian Coastal & Railway Trail',
                'municipality'   => 'San Fabian',
                'district'       => 'District 4',
                'difficulty'     => 'easy',
                'estimated_time' => 20,
                'description'    => 'Discover San Fabian’s 1717 coastal parish church overlooking Lingayen Gulf and the historic railway junction toward Camp One and Baguio.',
                'stops'          => [
                    'Parish of St. Fabian, Pope and Martyr',
                    'Old PNR San Fabian Station',
                ],
            ],
            [
                'name'           => 'Manaoag Marian Pilgrimage Trail',
                'municipality'   => 'Manaoag',
                'district'       => 'Manaoag',
                'difficulty'     => 'easy',
                'estimated_time' => 35,
                'description'    => 'Follow the historic devotion route from the Minor Basilica of Our Lady of the Rosary of Manaoag through the Spanish colonial town plaza to the 1908 Binday railway station.',
                'stops'          => [
                    'Minor Basilica of Our Lady of the Rosary of Manaoag',
                    'Historic Town Plaza and Street Grid',
                    'Old PNR Manaoag (Binday) Station',
                ],
            ],
        ];

        foreach ($trailsData as $tData) {
            $muniId = $tData['municipality']
                ? ($municipalities[$tData['municipality']]->id ?? null)
                : null;

            $trail = \App\Models\Trail::updateOrCreate(
                ['name' => $tData['name']],
                [
                    'municipality_id' => $muniId,
                    'district'        => $tData['district'],
                    'difficulty'      => $tData['difficulty'],
                    'estimated_time'  => $tData['estimated_time'],
                    'description'     => $tData['description'],
                ]
            );

            $syncMap = [];
            $order = 1;
            foreach ($tData['stops'] as $stopName) {
                $lm = $landmarkModels->get($stopName) ?? Landmark::where('name', $stopName)->first();
                if ($lm) {
                    $syncMap[$lm->id] = ['order' => $order++];
                }
            }

            if (! empty($syncMap)) {
                $trail->landmarks()->sync($syncMap);
            }
        }

        // Precompute ORS / fallback route segments for all seeded trails
        try {
            \Illuminate\Support\Facades\Artisan::call('trails:precompute-routes');
        } catch (\Throwable $e) {
            // Ignore if trail_segments migration hasn't run yet
        }
    }
}
