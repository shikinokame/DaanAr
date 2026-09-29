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

        User::firstOrCreate(
            ['email' => 'admin@daanar.ph'],
            [
                'name' => 'DaanAR Super Admin',
                'password' => 'password',
                'role' => 'super_admin',
                'municipality_id' => null,
            ]
        );

        $landmarks = [
            // ── Dagupan City ───────────────────────────────────────────────
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
                'is_featured' => true,
            ],

            // ── Manaoag ────────────────────────────────────────────────────
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
                'is_featured' => false,
            ],

            // ── Mangaldan ──────────────────────────────────────────────────
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
                'is_featured' => true,
            ],
            [
                'municipality' => 'Mangaldan',
                'name' => 'PNR Mangaldan Station',
                'description' => 'The PNR Mangaldan Station was an integral station on the Manila Railroad Company’s northern line extension extending from Dagupan toward San Fabian and La Union. During the early 20th century, the station spurred Mangaldan’s agricultural commerce—particularly carabao livestock and processed meat trading—into a thriving regional enterprise.',
                'short_description' => 'Historic railroad station on the Northern Luzon line extension.',
                'category' => 'historical',
                'era' => 'American Colonial',
                'address' => '3CG2+W3, Poblacion, Mangaldan, Pangasinan',
                'lat' => 16.07731300,
                'lng' => 120.40018800,
                'is_featured' => false,
            ],

            // ── San Jacinto ────────────────────────────────────────────────
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
                'is_featured' => true,
            ],

            // ── San Fabian ─────────────────────────────────────────────────
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
                'is_featured' => false,
            ],
        ];

        // Disable foreign key checks, wipe existing landmarks cleanly, and reseed
        Schema::disableForeignKeyConstraints();
        Landmark::truncate();
        Schema::enableForeignKeyConstraints();

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
