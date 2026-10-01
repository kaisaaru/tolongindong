<?php

namespace App\Enums;

enum AttachmentType: string
{
    case PICKUP_PROOF = 'pickup_proof';
    case COMPLETION_PROOF = 'completion_proof';
    case DISPUTE_EVIDENCE = 'dispute_evidence';
    case RECEIPT = 'receipt';

    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
