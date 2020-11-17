class CourseInfo implements Comparable<CourseInfo> {
  int term;
  int crn;
  String name;

  @override
  String toString() =>
      "Name: " + name + " CRN: " + crn.toString() + " Term: " + term.toString();

  @override
  bool operator ==(o) => o is CourseInfo && o.term == term && o.crn == crn;

  @override
  int get hashCode => (37 + term) * 37 + crn;

  @override
  int compareTo(CourseInfo other) {
    return name.compareTo(other.name);
  }

  Map<String, dynamic> toFirestoreObject() {
    return {"name": this.name, "crn": crn, "term": term};
  }

  CourseInfo.fromFirestore(Map<String, dynamic> course)
      : term = course["term"],
        crn = course["crn"],
        name = course["name"];

  CourseInfo({this.term, this.crn, this.name});
}
