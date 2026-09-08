/// Owner-only sideload switch. Never persisted in a save or paid entitlement.
///
/// The normal/public build leaves this false. Android bundle builds reject
/// this switch, so an ad-free phone candidate cannot accidentally go to Play.
const bool ownerPhoneNoAdsBuild = bool.fromEnvironment(
  'WILDCARD_OWNER_NO_ADS',
  defaultValue: false,
);
