/// Which conversation the patient is reading right now, if any.
///
/// Read by the live notification toast: a "New message" banner for the
/// thread already on screen is noise, since the thread itself updates.
class OpenConversation {
  String? id;
}
