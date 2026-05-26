{-# LANGUAGE OverloadedStrings #-}

module Auth.JWT where

import Crypto.Hash (SHA256)
import Crypto.MAC.HMAC (HMAC, hmac)
import Data.Aeson (FromJSON, ToJSON, (.=), (.:), object, parseJSON, withObject)
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Time.Clock (NominalDiffTime)

import qualified Data.Aeson as A
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64 as B64
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text.Encoding as TE

data AuthClaims = AuthClaims
  { acUserId :: !Text
  , acRole   :: !Text
  }

instance ToJSON AuthClaims where
  toJSON a = object
    [ "sub"  .= acUserId a
    , "role" .= acRole a
    ]

instance FromJSON AuthClaims where
  parseJSON = withObject "AuthClaims" $ \o ->
    AuthClaims
      <$> o .: "sub"
      <*> o .: "role"

makeToken :: ByteString -> NominalDiffTime -> AuthClaims -> IO ByteString
makeToken secret _expiry claims = do
  let header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"
      payload = BL.toStrict $ A.encode claims
      headerB64 = base64urlEncode header
      payloadB64 = base64urlEncode payload
      signingInput = headerB64 <> "." <> payloadB64
      sig = hmacSHA256 secret signingInput
      sigB64 = base64urlEncode sig
  pure $ signingInput <> "." <> sigB64

verifyToken :: ByteString -> ByteString -> Either Text AuthClaims
verifyToken secret token =
  case BS.split '.' token of
    [headerB64, payloadB64, sigB64] -> do
      let signingInput = headerB64 <> "." <> payloadB64
          expectedSig = hmacSHA256 secret signingInput
      sig <- note "Invalid signature encoding" $ base64urlDecode sigB64
      if sig == expectedSig
        then case A.decode (BL.fromStrict =<< base64urlDecode payloadB64) of
          Nothing       -> Left "Invalid claims format"
          Just claims   -> pure claims
        else Left "Signature verification failed"
    _ -> Left "Invalid JWT format"

hmacSHA256 :: ByteString -> ByteString -> ByteString
hmacSHA256 key msg = convert (hmac key msg :: HMAC SHA256)

base64urlEncode :: ByteString -> ByteString
base64urlEncode = BS.filter (/= '=') . BS.map toUrl . B64.encode
  where
    toUrl '+' = '-'
    toUrl '/' = '_'
    toUrl c   = c

base64urlDecode :: ByteString -> Either String ByteString
base64urlDecode = B64.decode . addPadding . BS.map fromUrl
  where
    fromUrl '-' = '+'
    fromUrl '_' = '/'
    fromUrl c   = c
    addPadding b = b <> BS.replicate padLen '='
      where
        r = BS.length b `mod` 4
        padLen = if r == 0 then 0 else 4 - r

note :: Text -> Maybe a -> Either Text a
note _ (Just a) = Right a
note e Nothing  = Left e
