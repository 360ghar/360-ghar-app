abstract class AppRoutes {
  static const splash = '/splash';
  static const phoneEntry = '/phone-entry';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const setPassword = '/set-password';
  static const profileCompletion = '/profile-completion';
  static const dashboard = '/dashboard';
  static const discover = '/discover'; // Swipe deck interface
  static const propertyDetails = '/property-details';
  // Deep link routes for property sharing
  static const propertyShortLink = '/p/:id'; // Short link: the360ghar.com/p/123
  static const propertyDeepLink = '/property/:id'; // Full link: the360ghar.com/property/123
  // OAuth redirect deep link (Supabase Google redirect flow).
  // Full URL to allowlist in Supabase Redirect URLs: ghar360://login-callback
  static const oauthRedirectScheme = 'ghar360';
  static const oauthRedirectHost = 'login-callback';
  static const oauthRedirectUrl = '$oauthRedirectScheme://$oauthRedirectHost';
  static const profile = '/profile';
  static const editProfile = '/edit-profile';
  static const likes = '/likes'; // Renamed from favourites for consistency
  static const visits = '/visits';
  static const explore = '/explore'; // Map interface
  static const tour = '/tour';
  static const preferences = '/preferences';
  static const privacy = '/privacy';
  static const help = '/help';
  static const feedback = '/feedback';
  static const about = '/about';
  // Tools and calculators
  static const tools = '/tools';
  static const areaConverter = '/tools/area-converter';
  static const loanEligibility = '/tools/loan-eligibility';
  static const emiCalculator = '/tools/emi-calculator';
  static const carpetArea = '/tools/carpet-area';
  static const documentChecklist = '/tools/document-checklist';
  static const capitalGains = '/tools/capital-gains';
  static const assistant = '/assistant';
}
