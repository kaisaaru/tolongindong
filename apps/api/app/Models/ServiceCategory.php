<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class ServiceCategory extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name',
        'base_fee',
        'requires_advance',
        'requires_proof_photo',
        'requires_pickup_address',
        'requires_destination_address',
    ];

    protected function casts(): array
    {
        return [
            'base_fee' => 'integer',
            'requires_advance' => 'boolean',
            'requires_proof_photo' => 'boolean',
            'requires_pickup_address' => 'boolean',
            'requires_destination_address' => 'boolean',
        ];
    }

    /**
     * Helper profiles that master this category.
     */
    public function helperProfiles(): BelongsToMany
    {
        return $this->belongsToMany(
            HelperProfile::class,
            'helper_service_category',
            'service_category_id',
            'helper_profile_id'
        );
    }
}
