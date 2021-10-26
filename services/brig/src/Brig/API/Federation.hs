{-# LANGUAGE RecordWildCards #-}

-- This file is part of the Wire Server implementation.
--
-- Copyright (C) 2020 Wire Swiss GmbH <opensource@wire.com>
--
-- This program is free software: you can redistribute it and/or modify it under
-- the terms of the GNU Affero General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option) any
-- later version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
-- details.
--
-- You should have received a copy of the GNU Affero General Public License along
-- with this program. If not, see <https://www.gnu.org/licenses/>.

module Brig.API.Federation (federationSitemap) where

import qualified Brig.API.Client as API
import Brig.API.Connection.Remote (performRemoteAction)
import Brig.API.Error (clientError)
import Brig.API.Handler (Handler)
import qualified Brig.API.User as API
import Brig.App (qualifyLocal)
import qualified Brig.Data.Connection as Data
import qualified Brig.Data.User as Data
import Brig.IO.Intra (notify)
import Brig.Types (PrekeyBundle, Relation (Accepted))
import Brig.Types.User.Event
import Brig.User.API.Handle
import Data.Domain
import Data.Handle (Handle (..), parseHandle)
import Data.Id (ClientId, UserId)
import Data.List.NonEmpty (nonEmpty)
import Data.List1
import Data.Qualified
import Data.Range
import qualified Gundeck.Types.Push as Push
import Imports
import Network.Wai.Utilities.Error ((!>>))
import Servant (ServerT)
import Servant.API.Generic (ToServantApi)
import Servant.Server.Generic (genericServerT)
import UnliftIO.Async (pooledForConcurrentlyN_)
import Wire.API.Federation.API.Brig hiding (Api (..))
import qualified Wire.API.Federation.API.Brig as Federated
import qualified Wire.API.Federation.API.Brig as FederationAPIBrig
import Wire.API.Federation.API.Common
import Wire.API.Message (UserClients)
import Wire.API.Routes.Internal.Brig.Connection
import Wire.API.Team.LegalHold (LegalholdProtectee (LegalholdPlusFederationNotImplemented))
import Wire.API.User (UserProfile)
import Wire.API.User.Client (PubClient, UserClientPrekeyMap)
import Wire.API.User.Client.Prekey (ClientPrekey)
import Wire.API.User.Search
import Wire.API.UserMap (UserMap)

federationSitemap :: ServerT (ToServantApi Federated.Api) Handler
federationSitemap =
  genericServerT $
    FederationAPIBrig.Api
      { Federated.getUserByHandle = getUserByHandle,
        Federated.getUsersByIds = getUsersByIds,
        Federated.claimPrekey = claimPrekey,
        Federated.claimPrekeyBundle = claimPrekeyBundle,
        Federated.claimMultiPrekeyBundle = claimMultiPrekeyBundle,
        Federated.searchUsers = searchUsers,
        Federated.getUserClients = getUserClients,
        Federated.sendConnectionAction = sendConnectionAction,
        Federated.onUserDeleted = onUserDeleted
      }

sendConnectionAction :: Domain -> NewConnectionRequest -> Handler NewConnectionResponse
sendConnectionAction originDomain NewConnectionRequest {..} = do
  active <- lift $ Data.isActivated ncrTo
  if active
    then do
      self <- qualifyLocal ncrTo
      let other = toRemoteUnsafe originDomain ncrFrom
      mconnection <- lift $ Data.lookupConnection self (qUntagged other)
      maction <- lift $ performRemoteAction self other mconnection ncrAction
      pure $ NewConnectionResponseOk maction
    else pure NewConnectionResponseUserNotActivated

getUserByHandle :: Handle -> Handler (Maybe UserProfile)
getUserByHandle handle = lift $ do
  maybeOwnerId <- API.lookupHandle handle
  case maybeOwnerId of
    Nothing ->
      pure Nothing
    Just ownerId ->
      listToMaybe <$> API.lookupLocalProfiles Nothing [ownerId]

getUsersByIds :: [UserId] -> Handler [UserProfile]
getUsersByIds uids =
  lift (API.lookupLocalProfiles Nothing uids)

claimPrekey :: (UserId, ClientId) -> Handler (Maybe ClientPrekey)
claimPrekey (user, client) = do
  API.claimLocalPrekey LegalholdPlusFederationNotImplemented user client !>> clientError

claimPrekeyBundle :: UserId -> Handler PrekeyBundle
claimPrekeyBundle user =
  API.claimLocalPrekeyBundle LegalholdPlusFederationNotImplemented user !>> clientError

claimMultiPrekeyBundle :: UserClients -> Handler UserClientPrekeyMap
claimMultiPrekeyBundle uc = API.claimLocalMultiPrekeyBundles LegalholdPlusFederationNotImplemented uc !>> clientError

-- | Searching for federated users on a remote backend should
-- only search by exact handle search, not in elasticsearch.
-- (This decision may change in the future)
searchUsers :: SearchRequest -> Handler [Contact]
searchUsers (SearchRequest searchTerm) = do
  let maybeHandle = parseHandle searchTerm
  maybeOwnerId <- maybe (pure Nothing) (lift . API.lookupHandle) maybeHandle
  case maybeOwnerId of
    Nothing -> pure []
    Just foundUser -> lift $ contactFromProfile <$$> API.lookupLocalProfiles Nothing [foundUser]

getUserClients :: GetUserClients -> Handler (UserMap (Set PubClient))
getUserClients (GetUserClients uids) = API.lookupLocalPubClientsBulk uids !>> clientError

onUserDeleted :: Domain -> UserDeletedNotification -> Handler EmptyResponse
onUserDeleted origDomain udn = lift $ do
  let deletedUser = toRemoteUnsafe origDomain (udnUser udn)
      connections = udnConnections udn
      event = pure . UserEvent $ UserDeleted (qUntagged deletedUser)
  acceptedLocals <-
    map csv2From
      . filter (\x -> csv2Status x == Accepted)
      <$> Data.lookupRemoteConnectionStatuses (fromRange connections) (fmap pure deletedUser)
  pooledForConcurrentlyN_ 16 (nonEmpty acceptedLocals) $ \(List1 -> recipients) ->
    notify event (tUnqualified deletedUser) Push.RouteDirect Nothing (pure recipients)
  Data.deleteRemoteConnections deletedUser connections
  pure EmptyResponse
