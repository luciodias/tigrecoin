{-# LANGUAGE OverloadedStrings #-}

module Auth.JWT where

import Control.Monad.Except (runExceptT)
import Data.Aeson (FromJSON, ToJSON, (.=), (.:), object, parseJSON, withObject)
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Time.Clock (NominalDiffTime, addUTCTime, getCurrentTime)
import Jose.JWA (Alg(HS256))
import Jose.JWK (JWK, jwkFromOctets)
import Jose.JWS (sign, verify, decodeCompact, encodeCompact, JWSHeader(..))

import qualified Data.Aeson as A
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL

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

type Jwk = JWK

makeJwk :: ByteString -> Jwk
makeJwk = jwkFromOctets

makeToken :: Jwk -> NominalDiffTime -> AuthClaims -> IO ByteString
makeToken jwk _expiry claims = do
  let payload = A.encode claims
  result <- runExceptT $ sign jwk (mempty { jwsAlg = HS256 }) (BL.toStrict payload)
  case result of
    Left err   -> error $ "JWT signing failed: " <> show err
    Right jws  -> pure $ encodeCompact jws

verifyToken :: Jwk -> ByteString -> IO (Either Text AuthClaims)
verifyToken jwk token = do
  case decodeCompact token of
    Left err  -> pure $ Left "Invalid JWT"
    Right jws -> do
      result <- runExceptT $ verify jwk jws
      case result of
        Left _      -> pure $ Left "Signature verification failed"
        Right payload -> case A.decode (BL.fromStrict payload) of
          Nothing      -> pure $ Left "Invalid claims format"
          Just claims  -> pure $ Right claims
