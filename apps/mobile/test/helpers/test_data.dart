import 'package:mobile/features/household/household_models.dart';
import 'package:mobile/features/order/order_models.dart';
import 'package:mobile/models/service_category.dart';

/// Data bersama widget test: kategori, alamat tersimpan, dan helper,
/// berbentuk sama dengan hasil API.

const testDelivery = ServiceCategory(
  id: 1,
  code: 'delivery',
  name: 'Delivery',
  baseFee: 10000,
  requiresAdvance: false,
  requiresProofPhoto: false,
  requiresPickupAddress: true,
  requiresDestinationAddress: true,
);

const testPersonal = ServiceCategory(
  id: 2,
  code: 'personal',
  name: 'Personal',
  baseFee: 10000,
  requiresAdvance: false,
  requiresProofPhoto: false,
  requiresPickupAddress: false,
  requiresDestinationAddress: false,
);

const testHousehold = ServiceCategory(
  id: 3,
  code: 'household',
  name: 'Household',
  baseFee: 5000,
  requiresAdvance: false,
  requiresProofPhoto: false,
  requiresPickupAddress: false,
  requiresDestinationAddress: true,
);

const testCategories = [testDelivery, testPersonal, testHousehold];

const testHome = SavedAddress(
  id: 11,
  label: 'Rumah',
  fullAddress: 'Jl. Sukaati V No.19, Pasirluyu, Kec. Regol, Kota Bandung',
  kind: AddressKind.home,
  latitude: -6.9387,
  longitude: 107.6167,
  isPrimary: true,
);

const testOffice = SavedAddress(
  id: 12,
  label: 'Kantor',
  fullAddress: 'Jl. Asia Afrika No.8, Braga, Kec. Sumur Bandung',
  kind: AddressKind.office,
  latitude: -6.9218,
  longitude: 107.6071,
);

const testAddresses = [testHome, testOffice];

const testHelpers = [
  HourlyHelper(
    id: 'h-1',
    name: 'Agus Nomercy',
    rating: 5,
    reviewCount: 421,
    completedCount: 1240,
    hourlyRate: 40000,
    distanceKm: 1.2,
  ),
  HourlyHelper(
    id: 'h-2',
    name: 'Budi Santoso',
    rating: 4.6,
    reviewCount: 88,
    completedCount: 150,
    hourlyRate: 35000,
    distanceKm: 3.4,
  ),
];

const testListings = [
  HelperListing(
    id: 'h-1',
    name: 'Agus Nomercy',
    rating: 5,
    reviewCount: 421,
    completedCount: 1240,
    price: 40000,
    unit: 'jam',
    subcategory: '',
    tags: ['Personal', 'Household'],
    about: '',
  ),
  HelperListing(
    id: 'h-3',
    name: 'Citra Lestari',
    rating: 4.8,
    reviewCount: 64,
    completedCount: 90,
    price: 30000,
    unit: 'jam',
    subcategory: '',
    tags: ['Personal'],
    about: '',
  ),
];
