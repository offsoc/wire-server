{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns      #-}

module Brig.Email
    ( -- * Validation
      validateEmail

      -- * Unique Keys
    , EmailKey
    , mkEmailKey
    , emailKeyUniq
    , emailKeyOrig

      -- * Re-exports
    , Email (..)

      -- * MIME Re-exports
    , Mail (..)
    , emptyMail
    , plainPart
    , htmlPart
    , Address (..)
    , mkMimeAddress

      -- * AWS Re-exports
    , Aws.sendMail
    ) where

import Brig.Types
import Control.Applicative (optional)
import Control.Error (hush)
import Data.Attoparsec.ByteString.Char8
import Data.Monoid
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import Network.Mail.Mime

import qualified Brig.Aws            as Aws
import qualified Data.Text           as Text
import qualified Text.Email.Validate as Email

-------------------------------------------------------------------------------
-- Validation

validateEmail :: Email -> Maybe Email
validateEmail (fromEmail -> e) =
    validateLength  >>=
    validateRfc5322 >>=
    validateDomain  >>=
        Just . mkEmail
  where
    validateLength | Text.length e <= 100 = Just (encodeUtf8 e)
                   | otherwise            = Nothing

    validateRfc5322 = either (const Nothing) Just . Email.validate

    -- cf. https://en.wikipedia.org/wiki/Email_address#Domain
    -- n.b. We do not allow IP address literals, comments or non-ASCII
    --      characters, mostly because SES (and probably many other mail
    --      systems) don't support that (yet?) either.
    validateDomain e' = hush (parseOnly parser (Email.domainPart e'))
      where
        parser = label *> many1 (char '.' *> label) *> endOfInput *> pure e'
        label  = satisfy (inClass "a-zA-Z")
              *> count 61 (optional (satisfy (inClass "-a-zA-Z0-9")))
              *> optional (satisfy (inClass "a-zA-Z0-9"))

    mkEmail v = Email (mkLocal v) (mkDomain v)
    mkLocal   = decodeUtf8 . Email.localPart
    mkDomain  = decodeUtf8 . Email.domainPart

-------------------------------------------------------------------------------
-- Unique Keys

-- | An 'EmailKey' is an 'Email' in a form that serves as a unique lookup key.
data EmailKey = EmailKey
    { emailKeyUniq :: !Text
    , emailKeyOrig :: !Email
    }

instance Show EmailKey where
    showsPrec _ = shows . emailKeyUniq

instance Eq EmailKey where
    (EmailKey k _) == (EmailKey k' _) = k == k'

-- | Turn an 'Email' into an 'EmailKey'.
--
-- The following transformations are performed:
--
--   * Both local and domain parts are forced to lowercase to make
--     e-mail addresses fully case-insensitive.
--   * "+" suffixes on the local part are stripped unless the domain
--     part is contained in a trusted whitelist.
--
mkEmailKey :: Email -> EmailKey
mkEmailKey orig@(Email local domain) =
    let uniq = Text.toLower local' <> "@" <> Text.toLower domain
    in EmailKey uniq orig
  where
    local' | domain `notElem` trusted = Text.takeWhile (/= '+') local
           | otherwise                = local

    trusted = ["wearezeta.com", "wire.com", "simulator.amazonses.com"]

-------------------------------------------------------------------------------
-- MIME Conversions

-- | Construct a MIME 'Address' from the given display 'Name' and 'Email'
-- address that does not exceed 320 bytes in length when rendered for use
-- in SMTP, which is a safe limit for most mail servers (including those of
-- Amazon SES). The display name is only included if it fits within that
-- limit, otherwise it is dropped.
mkMimeAddress :: Name -> Email -> Address
mkMimeAddress name email =
    let addr = Address (Just (fromName name)) (fromEmail email)
    in if Text.compareLength (renderAddress addr) 320 == GT
        then Address Nothing (fromEmail email)
        else addr

