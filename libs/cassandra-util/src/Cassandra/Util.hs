module Cassandra.Util where

import Imports hiding (init)
import Cassandra
import Cassandra.Settings
import Data.Text (unpack)
import Data.Time (UTCTime)
import Data.Time.Clock.POSIX(posixSecondsToUTCTime)

import qualified Database.CQL.IO.Tinylog as CT
import qualified System.Logger as Log

type Writetime a = Int64

writeTimeToUTC :: Writetime a -> UTCTime
writeTimeToUTC = posixSecondsToUTCTime . fromIntegral . (`div` 1000000)

defInitCassandra :: Text -> Text -> Word16 -> Log.Logger -> IO ClientState
defInitCassandra ks h p lg =
    init
        $ setLogger (CT.mkLogger lg)
        . setPortNumber (fromIntegral p)
        . setContacts (unpack h) []
        . setKeyspace (Keyspace ks)
        $ defSettings
