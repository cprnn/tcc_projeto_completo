class Experience {
  double experienceCollected = 0;
  double experiencePerFruit = 25;
  //double experiencePerEnemy = 100;

  void incrementExperincePerFruitCollected() {
    experienceCollected += experiencePerFruit;
  }

//  void incrementExperincePerEnemy() {
//    experienceCollected += experiencePerEnemy;
//  }

  double getExperienceCollected() {
    return experienceCollected;
  }

  void resetExperience() {
    experienceCollected = 0;
  }
}
