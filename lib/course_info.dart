class CourseInfo {
  String name;
  int crn;
  int term;

  @override
  String toString() {
    return "Name: " +
        name +
        " CRN: " +
        crn.toString() +
        " Term: " +
        term.toString();
  }

  Map<String, dynamic> toFirestoreObject() {
    return {"name": this.name, "crn": crn, "term": term};
  }

  CourseInfo({this.name, this.crn, this.term});
}
