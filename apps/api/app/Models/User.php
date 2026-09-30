<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, HasUuids, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'full_name',
        'phone_number',
        'email',
        'password',
        'google_id',
        'photo_url',
        'verification_status',
        'is_admin',
        'is_suspended',
        'suspended_reason',
        'phone_verified_at',
        'email_verified_at',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'phone_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_admin' => 'boolean',
            'is_suspended' => 'boolean',
        ];
    }

    /**
     * User has one TD-Wallet.
     */
    public function wallet(): HasOne
    {
        return $this->hasOne(Wallet::class);
    }

    /**
     * User has one optional Helper Profile (DEC-01 Dual Role).
     */
    public function helperProfile(): HasOne
    {
        return $this->hasOne(HelperProfile::class);
    }

    /**
     * User can submit verification requests.
     */
    public function verificationRequests(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(VerificationRequest::class);
    }

    /**
     * Check if user has registered as a helper.
     */
    public function isHelper(): bool
    {
        return $this->helperProfile !== null;
    }

    /**
     * Check if user is an approved helper.
     */
    public function isVerifiedHelper(): bool
    {
        return $this->verification_status === 'verified' &&
            $this->helperProfile !== null &&
            $this->helperProfile->isApproved();
    }

    /**
     * Masked phone number (DEC-14 no 11, NFR-SEC-04).
     */
    public function maskedPhone(): ?string
    {
        if (!$this->phone_number) {
            return null;
        }
        $len = strlen($this->phone_number);
        if ($len <= 8) {
            return $this->phone_number;
        }
        return substr($this->phone_number, 0, 4) . 'xxxx' . substr($this->phone_number, -4);
    }
}

