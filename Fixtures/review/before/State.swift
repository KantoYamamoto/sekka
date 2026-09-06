struct State {
  func reset() {
    prepare()
    current = previous
    finish()
  }
}
