{-# LANGUAGE OverloadedStrings #-}

module Auth.Middleware where

import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8')
import Network.Wai (Request, requestHeaders)
import Servant (Handler, err401, errBody, throwError)
import Servant.Server.Experimental.Auth (AuthHandler, mkAuthHandler)

import Auth.JWT (AuthClaims(..), Jwk, makeJwk, verifyToken)

import qualified Data.ByteString as BS
import qualified Data.Text as T

data AuthUser = AuthUser
  { auUserId :: !Text
  , auRole   :: !Text
  }

mkAuthMiddleware :: ByteString -> (Request -> Handler AuthUser)
mkAuthMiddleware jwtSecret =
  let jwk = makeJwk jwtSecret
  in \req -> do
    let mHeader = lookup "Authorization" (requestHeaders req)
    case mHeader of
      Nothing -> throwError $ err401 { errBody = "Missing Authorization header" }
      Just bearer -> do
        let token = parseBearer bearer
        case token of
          Nothing -> throwError $ err401 { errBody = "Invalid Authorization format" }
          Just t  -> do
            result <- liftIO $ verifyToken jwk t
            case result of
              Left err -> throwError $ err401 { errBody = encodeText err }
              Right claims -> pure $ AuthUser (acUserId claims) (acRole claims)

parseBearer :: ByteString -> Maybe ByteString
parseBearer bs =
  let prefix = "Bearer "
      plen   = BS.length prefix
  in if BS.take plen bs == prefix
     then Just (BS.drop plen bs)
     else Nothing

encodeText :: Text -> ByteString
encodeText = BS.pack . T.unpack
