{-# LANGUAGE OverloadedStrings #-}

module Types.Errors where

import Data.Aeson (object, (.=))
import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)
import Servant (ServerError, err401, err403, err404, err409, err500, err422, errBody)

import qualified Data.Aeson as A

data AppError
  = NotFound Text
  | Unauthorized Text
  | Forbidden Text
  | Conflict Text
  | ValidationError Text
  | InternalError Text

appErrorToServerError :: AppError -> ServerError
appErrorToServerError (NotFound t)        = err404 { errBody = encodeText t }
appErrorToServerError (Unauthorized t)    = err401 { errBody = encodeText t }
appErrorToServerError (Forbidden t)       = err403 { errBody = encodeText t }
appErrorToServerError (Conflict t)        = err409 { errBody = encodeText t }
appErrorToServerError (ValidationError t) = err422 { errBody = encodeText t }
appErrorToServerError (InternalError _)   = err500

encodeText :: Text -> ByteString
encodeText t = A.encode (object ["error" .= t])
