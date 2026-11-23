// Application constants for PolyFind
class AppConstants {
  static const String schoolEmailDomain = '@thenyeripoly.ac.ke';

  // App info
  static const String appName = 'PolyFind';
  static const String appTagline =
      'Lost & Found for Nyeri National Polytechnic';

  // Supabase tables
  static const String usersCollection = 'users';
  static const String itemsCollection = 'items';
  static const String claimsCollection = 'claims';
  static const String itemPhotosBucket = 'item-photos';
  static const int maxItemImageBytes = 300 * 1024;

  // Item types
  static const String itemTypeLost = 'lost';
  static const String itemTypeFound = 'found';

  // Item statuses
  static const String itemStatusOpen = 'open';
  static const String itemStatusClaimed = 'claimed';
  static const String itemStatusReturned = 'returned';
  static const String itemStatusArchived = 'archived';

  // Claim statuses
  static const String claimStatusPending = 'pending';
  static const String claimStatusApproved = 'approved';
  static const String claimStatusRejected = 'rejected';

  // User roles
  static const String roleStudent = 'student';
  static const String roleStaff = 'staff';
  static const String roleAdmin = 'admin';

  // Categories
  static const List<String> categories = [
    'Phone',
    'ID Card',
    'Keys',
    'Bottle',
    'Bag',
    'Books',
    'Clothing',
    'Other',
  ];

  // Storage paths
  static const String itemImagesPath = 'item_images';
  static const String profileImagesPath = 'profile_images';

  // Pagination
  static const int itemsPerPage = 10;

  // Archive threshold (days)
  static const int archiveAfterDays = 60;

  // Image compression
  static const int maxImageWidth = 1024;
  static const int maxImageHeight = 1024;
  static const int imageQuality = 80;

  // Validation
  static const int minTitleLength = 3;
  static const int maxTitleLength = 50;
  static const int minDescriptionLength = 10;
  static const int maxDescriptionLength = 500;
  static const int minVerificationAnswerLength = 5;

  // Routes
  static const String routeSplash = '/';
  static const String routeAuth = '/auth';
  static const String routeLogin = '/auth/login';
  static const String routeRegister = '/auth/register';
  static const String routeHome = '/home';
  static const String routePostItem = '/post-item';
  static const String routeItemDetail = '/item/:itemId';
  static const String routeMyActivity = '/my-activity';
  static const String routeProfile = '/profile';
  static const String routeAdmin = '/admin';
  static const String routeClaims = '/claims';
}
