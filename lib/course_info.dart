class CourseInfo {
  String name;
  int crn;

  @override
  String toString() {
    return "Name: " + name + " CRN: " + crn.toString();
  }

  CourseInfo({this.name, this.crn});
}
