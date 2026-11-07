/// Subject categories shown in the AI Coach (plan maker, explainer and notes).
/// Any student can use the app - pick the closest track, or type any subject.
class StudyCategory {
  final String name;
  final String emoji;
  final List<String> examples; // example topics for the Explainer tab
  const StudyCategory(this.name, this.emoji, this.examples);
}

const List<StudyCategory> kStudyCategories = [
  StudyCategory('School (Class 1-12)', '🎒', ['Photosynthesis', 'Pythagoras theorem', 'Water cycle', 'Parts of speech']),
  StudyCategory('Science', '🔬', ['Newton\'s laws of motion', 'Mitosis vs meiosis', 'Periodic table trends', 'Electromagnetic induction']),
  StudyCategory('Mathematics', '➗', ['Integration by parts', 'Probability basics', 'Matrices and determinants', 'Mathematical induction']),
  StudyCategory('Engineering', '⚙️', ['Operating system deadlock', 'Ohm\'s law', 'Thermodynamics first law', 'Beam bending']),
  StudyCategory('Coding', '💻', ['OOP concepts in Java', 'Quicksort', 'Dynamic programming', 'REST API vs GraphQL']),
  StudyCategory('Medical', '🩺', ['Cardiac cycle', 'Krebs cycle', 'Nephron physiology', 'Brachial plexus']),
  StudyCategory('Pharmacy & Nursing', '💊', ['Pharmacokinetics', 'Drug receptors', 'Nursing process', 'Vital signs']),
  StudyCategory('Law', '⚖️', ['Article 21 of the Indian Constitution', 'Doctrine of precedent', 'Contract essentials', 'Tort of negligence']),
  StudyCategory('Commerce & Finance', '📊', ['Balance sheet basics', 'Time value of money', 'GST in India', 'Cost-volume-profit analysis']),
  StudyCategory('Economics', '📈', ['Supply and demand', 'GDP vs GNP', 'Inflation and monetary policy', 'Game theory basics']),
  StudyCategory('Business & Management', '🏢', ['SWOT analysis', 'Porter\'s five forces', 'Marketing mix 4Ps', 'Leadership theories']),
  StudyCategory('History & Civics', '🏛️', ['French Revolution', 'Indian freedom movement', 'Cold War', 'Separation of powers']),
  StudyCategory('Languages & Literature', '📖', ['Figures of speech', 'Shakespeare\'s Hamlet themes', 'Tenses in English', 'Essay writing structure']),
  StudyCategory('Arts & Design', '🎨', ['Color theory', 'Renaissance art', 'Principles of design', 'Typography basics']),
  StudyCategory('Psychology & Social Science', '🧠', ['Classical vs operant conditioning', 'Maslow\'s hierarchy', 'Socialization', 'Research methods']),
  StudyCategory('Competitive Exams', '🏆', ['Indian polity for UPSC', 'Quantitative aptitude shortcuts', 'Logical reasoning patterns', 'Current affairs strategy']),
  StudyCategory('Other', '✨', ['Time management', 'Critical thinking', 'Public speaking', 'Note-taking methods']),
];

List<String> get kCategoryNames => kStudyCategories.map((c) => c.name).toList();

StudyCategory categoryByName(String name) =>
    kStudyCategories.firstWhere((c) => c.name == name, orElse: () => kStudyCategories[1]);

/// True for categories that should use coding practice platforms (LeetCode, HackerRank...).
bool isCodingCategory(String name) => name == 'Coding';
