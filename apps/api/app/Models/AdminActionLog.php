<?php

namespace App\Models;

use App\Enums\AdminActionType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminActionLog extends Model
{
    use HasFactory;

    const UPDATED_AT = null;

    protected $fillable = [
        'admin_user_id',
        'action_type',
        'target_entity',
        'target_id',
        'note',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'action_type' => AdminActionType::class,
            'created_at' => 'datetime',
        ];
    }

    /**
     * Admin yang melakukan tindakan.
     */
    public function admin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'admin_user_id');
    }
}
