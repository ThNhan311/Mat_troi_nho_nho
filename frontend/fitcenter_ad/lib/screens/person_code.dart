/// The first block of an id, upper case: short enough to read out loud.
String personCode(String id) =>
    (id.length > 8 ? id.substring(0, 8) : id).toUpperCase();
