class OnboardingModel {
  final int id;
  final String title;
  final String subtitle;
  final String imagePath;

  OnboardingModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });
}

final List<OnboardingModel> onboardingPages = [
  OnboardingModel(
    id: 1,
    title: "Drive to Earn.",
    subtitle: "Take control of your income with real-time tracking and instant payouts. Your hustle, your rewards.",
    imagePath: "assets/images/onboarding_earn.png", // Image of driver with phone/tablet
  ),  
  OnboardingModel(
    id: 2,
    title: "Your Safety First.",
    subtitle: "Advanced GPS tracking and 24/7 emergency support for every trip. We’ve got your back on every road.",
    imagePath: "assets/images/onboarding_safety.png", // Image of driver fleet/community
  ),
  OnboardingModel(
    id: 3,
    title: "Fast-Track Approval.",
    subtitle: "Upload your documents and get on the road in 24 hours. Simple, digital, and transparent.",
    imagePath: "assets/images/onboarding_start.png", // Hero shot of driver next to vehicle
  ),
];