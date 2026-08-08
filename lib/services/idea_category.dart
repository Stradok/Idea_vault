enum IdeaCategory {
  delivery,
  food,
  health,
  education,
  ecommerce,
  travel,
  fitness,
  finance,
  realestate,
  technology,
  sustainability,
  fashion,
  generic;

  String get label {
    switch (this) {
      case IdeaCategory.delivery:
        return 'Delivery & Logistics';
      case IdeaCategory.food:
        return 'Food & Restaurants';
      case IdeaCategory.health:
        return 'Health & Wellness';
      case IdeaCategory.education:
        return 'Education & Learning';
      case IdeaCategory.ecommerce:
        return 'E-commerce & Retail';
      case IdeaCategory.travel:
        return 'Travel & Hospitality';
      case IdeaCategory.fitness:
        return 'Fitness & Sports';
      case IdeaCategory.finance:
        return 'Finance & Payments';
      case IdeaCategory.realestate:
        return 'Real Estate';
      case IdeaCategory.technology:
        return 'Tech & SaaS';
      case IdeaCategory.sustainability:
        return 'Sustainability';
      case IdeaCategory.fashion:
        return 'Fashion & Apparel';
      case IdeaCategory.generic:
        return 'General Business';
    }
  }
}

const Map<IdeaCategory, List<String>> _keywords = {
  IdeaCategory.delivery: [
    'delivery',
    'courier',
    'logistics',
    'shipping',
    'parcel',
    'dispatch',
    'riders',
    'last mile',
  ],
  IdeaCategory.food: [
    'food',
    'restaurant',
    'cafe',
    'snack',
    'meal',
    'bakery',
    'catering',
    'recipe',
    'kitchen',
    'dining',
  ],
  IdeaCategory.health: [
    'health',
    'medical',
    'clinic',
    'therapy',
    'wellness',
    'doctor',
    'pharmacy',
    'mental',
  ],
  IdeaCategory.education: [
    'education',
    'learn',
    'course',
    'tutor',
    'school',
    'teach',
    'training',
    'student',
    'study',
  ],
  IdeaCategory.ecommerce: [
    'ecommerce',
    'e-commerce',
    'shop',
    'store',
    'retail',
    'marketplace',
    'buy',
    'sell',
    'product',
  ],
  IdeaCategory.travel: [
    'travel',
    'tour',
    'hotel',
    'booking',
    'trip',
    'vacation',
    'hostel',
    'itinerary',
  ],
  IdeaCategory.fitness: [
    'fitness',
    'gym',
    'yoga',
    'workout',
    'sport',
    'coach',
    'running',
    'exercise',
  ],
  IdeaCategory.finance: [
    'finance',
    'payment',
    'bank',
    'invest',
    'fintech',
    'loan',
    'insurance',
    'budget',
    'crypto',
    'money',
  ],
  IdeaCategory.realestate: [
    'real estate',
    'property',
    'rent',
    'housing',
    'apartment',
    'mortgage',
    'land',
    'broker',
  ],
  IdeaCategory.technology: [
    'app',
    'software',
    'saas',
    'platform',
    'ai',
    'automation',
    'tech',
    'data',
    'cloud',
    'digital',
    'website',
  ],
  IdeaCategory.sustainability: [
    'sustain',
    'eco',
    'green',
    'recycl',
    'solar',
    'organic',
    'environment',
    'plastic',
  ],
  IdeaCategory.fashion: [
    'fashion',
    'clothing',
    'apparel',
    'style',
    'designer',
    'brand',
    'wear',
    'outfit',
  ],
};

IdeaCategory detectCategory(String text) {
  final lower = text.toLowerCase();
  var best = IdeaCategory.generic;
  var bestScore = 0;
  _keywords.forEach((category, words) {
    var score = 0;
    for (final word in words) {
      if (lower.contains(word)) score++;
    }
    if (score > bestScore) {
      bestScore = score;
      best = category;
    }
  });
  return best;
}
