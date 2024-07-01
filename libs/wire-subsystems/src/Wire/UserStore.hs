{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -Wno-ambiguous-fields #-}

module Wire.UserStore where

import Data.Default
import Data.Handle
import Data.Id
import Imports
import Polysemy
import Polysemy.Error
import Wire.API.User
import Wire.Arbitrary
import Wire.StoredUser

-- | Update of any "simple" attributes (ones that do not involve locking, like handle, or
-- validation protocols, like email).
--
-- | see 'UserProfileUpdate'.
data StoredUserUpdate = MkStoredUserUpdate
  { name :: Maybe Name,
    pict :: Maybe Pict,
    assets :: Maybe [Asset],
    accentId :: Maybe ColourId,
    locale :: Maybe Locale,
    supportedProtocols :: Maybe (Set BaseProtocolTag)
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving (Arbitrary) via GenericUniform StoredUserUpdate

instance Default StoredUserUpdate where
  def = MkStoredUserUpdate Nothing Nothing Nothing Nothing Nothing Nothing

-- | Update user handle (this involves several http requests for locking the required handle).
-- The old/previous handle (for deciding idempotency).
data StoredUserHandleUpdate = MkStoredUserHandleUpdate
  { old :: Maybe Handle,
    new :: Handle
  }
  deriving stock (Eq, Ord, Show, Generic)
  deriving (Arbitrary) via GenericUniform StoredUserHandleUpdate

data StoredUserUpdateError = StoredUserUpdateHandleExists

-- | Effect containing database logic around 'StoredUser'.  (Example: claim handle lock is
-- database logic; validate handle is application logic.)
data UserStore m a where
  GetUser :: UserId -> UserStore m (Maybe StoredUser)
  UpdateUser :: UserId -> StoredUserUpdate -> UserStore m ()
  UpdateUserHandleEither :: UserId -> StoredUserHandleUpdate -> UserStore m (Either StoredUserUpdateError ())
  DeleteUser :: User -> UserStore m ()
  -- | This operation looks up a handle but is guaranteed to not give you stale locks.
  --   It is potentially slower and less resilient than 'GlimpseHandle'.
  LookupHandle :: Handle -> UserStore m (Maybe UserId)
  -- | The interpretation for 'LookupHandle' and 'GlimpseHandle'
  --   may differ in terms of how consistent they are.  If that
  --   matters for the interpretation, this operation may give you stale locks,
  --   but is faster and more resilient.
  GlimpseHandle :: Handle -> UserStore m (Maybe UserId)
  LookupStatus :: UserId -> UserStore m (Maybe AccountStatus)
  -- | Whether the account has been activated by verifying
  --   an email address or phone number.
  IsActivated :: UserId -> UserStore m Bool

makeSem ''UserStore

updateUserHandle ::
  (Member UserStore r, Member (Error StoredUserUpdateError) r) =>
  UserId ->
  StoredUserHandleUpdate ->
  Sem r ()
updateUserHandle uid update = either throw pure =<< updateUserHandleEither uid update
