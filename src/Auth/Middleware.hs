{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Auth.Middleware where

import Servant.API.Experimental.Auth (AuthProtect)
import Servant.Server.Experimental.Auth (AuthServerData)

import Data.ByteString (ByteString)
import Data.Text (Text)
import Network.Wai (Request, requestHeaders)
import Servant (Handler, err401, errBody, throwError)

import Auth.JWT (AuthClaims(..), verifyToken)

import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

data AuthUser = AuthUser
  { auUserId :: !Text
  , auRole   :: !Text
  }

type instance AuthServerData (AuthProtect "jwt-auth") = AuthUser

mkAuthMiddleware :: ByteString -> (Request -> Handler AuthUser)
mkAuthMiddleware jwtSecret = \req -> do
    let mHeader = lookup "Authorization" (requestHeaders req)
    case mHeader of
      Nothing -> throwError $ err401 { errBody = "Missing Authorization header" }
      Just bearer -> do
        let token = parseBearer bearer
        case token of
          Nothing -> throwError $ err401 { errBody = "Invalid Authorization format" }
          Just t  -> do
            result <- pure $ verifyToken jwtSecret t
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

encodeText :: Text -> BL.ByteString
encodeText = BL.fromStrict . TE.encodeUtf8
