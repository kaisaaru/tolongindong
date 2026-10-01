<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Address extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'label',
        'full_address',
        'latitude',
        'longitude',
        'landmark_note',
        'is_primary',
    ];

    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
            'is_primary' => 'boolean',
        ];
    }

    /**
     * Pengguna pemilik alamat.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
