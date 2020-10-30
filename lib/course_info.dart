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

  CourseInfo({this.name, this.crn, this.term});
}
