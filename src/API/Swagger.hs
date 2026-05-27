{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module API.Swagger (swaggerSpec, docsApp) where

import Control.Lens ((.~), (?~), (&))
import Data.ByteString.Lazy (ByteString)
import Data.Proxy (Proxy(..))
import Data.Swagger
  (Swagger, SwaggerType(..), ToSchema(..), NamedSchema(..),
   Referenced(..), Schema, declareNamedSchema)
import Data.Text (Text)
import Network.HTTP.Types (status200, status404)
import Network.Wai (Application, pathInfo, responseLBS)
import Servant ((:>), (:<|>)(..))
import Servant.Swagger (toSwagger)

import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy.Char8 as BL8
import qualified Data.HashMap.Strict.InsOrd as IHM
import qualified Data.Swagger as S

import API.Auth (AuthAPI)
import API.User (UserAPI)
import API.Wallet (WalletAPI)
import API.Transaction (TransactionAPI)
import Models.User (RegisterRequest(..), LoginRequest(..), UpdateUserRequest(..), UserResponse(..))
import Models.Wallet (WalletResponse(..), DepositRequest(..), WithdrawRequest(..))
import Models.Transaction (TransactionResponse(..))

stringSchema :: Schema
stringSchema = mempty & S.type_ ?~ S.SwaggerString

numberSchema :: Schema
numberSchema = mempty & S.type_ ?~ S.SwaggerNumber

objectSchema :: [(Text, Referenced Schema)] -> [S.ParamName] -> Schema
objectSchema props reqs = mempty
  & S.type_ ?~ S.SwaggerObject
  & S.properties .~ IHM.fromList props
  & S.required .~ reqs

instance ToSchema RegisterRequest where
  declareNamedSchema _ = pure $ NamedSchema (Just "RegisterRequest")
    (objectSchema
      [("name"    , Inline stringSchema)
      ,("email"   , Inline stringSchema)
      ,("password", Inline stringSchema)]
      ["name", "email", "password"])

instance ToSchema LoginRequest where
  declareNamedSchema _ = pure $ NamedSchema (Just "LoginRequest")
    (objectSchema
      [("email"   , Inline stringSchema)
      ,("password", Inline stringSchema)]
      ["email", "password"])

instance ToSchema UpdateUserRequest where
  declareNamedSchema _ = pure $ NamedSchema (Just "UpdateUserRequest")
    (objectSchema
      [("name" , Inline stringSchema)
      ,("email", Inline stringSchema)]
      ["name", "email"])

instance ToSchema UserResponse where
  declareNamedSchema _ = pure $ NamedSchema (Just "UserResponse")
    (objectSchema
      [("id"        , Inline stringSchema)
      ,("name"      , Inline stringSchema)
      ,("email"     , Inline stringSchema)
      ,("role"      , Inline stringSchema)
      ,("created_at", Inline stringSchema)]
      ["id", "name", "email", "role", "created_at"])

instance ToSchema WalletResponse where
  declareNamedSchema _ = pure $ NamedSchema (Just "WalletResponse")
    (objectSchema
      [("id"     , Inline stringSchema)
      ,("balance", Inline numberSchema)]
      ["id", "balance"])

instance ToSchema DepositRequest where
  declareNamedSchema _ = pure $ NamedSchema (Just "DepositRequest")
    (objectSchema
      [("amount", Inline numberSchema)]
      ["amount"])

instance ToSchema WithdrawRequest where
  declareNamedSchema _ = pure $ NamedSchema (Just "WithdrawRequest")
    (objectSchema
      [("amount", Inline numberSchema)]
      ["amount"])

instance ToSchema TransactionResponse where
  declareNamedSchema _ = pure $ NamedSchema (Just "TransactionResponse")
    (objectSchema
      [("id"         , Inline stringSchema)
      ,("wallet_id"  , Inline stringSchema)
      ,("type"       , Inline stringSchema)
      ,("amount"     , Inline numberSchema)
      ,("description", Inline stringSchema)
      ,("created_at" , Inline stringSchema)]
      ["id", "wallet_id", "type", "amount", "description", "created_at"])

type SwaggerAPI = "api" :> (
    UserAPI :<|> WalletAPI :<|> TransactionAPI
    :<|> AuthAPI
  )

swaggerApi :: Proxy SwaggerAPI
swaggerApi = Proxy

swaggerSpec :: Swagger
swaggerSpec = toSwagger swaggerApi
  & S.info . S.title   .~ "TigreCoin API"
  & S.info . S.version .~ "0.1.0"
  & S.info . S.description ?~ "Carteira digital - Prova de conceito"
  & S.host ?~ "localhost:8080"
  & S.basePath ?~ "/api"

swaggerJson :: ByteString
swaggerJson = A.encode swaggerSpec

swaggerHtml :: ByteString
swaggerHtml = BL8.pack $ mconcat
  [ "<!DOCTYPE html><html lang=\"en\"><head>"
  , "<meta charset=\"UTF-8\">"
  , "<title>TigreCoin API</title>"
  , "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css\">"
  , "</head><body>"
  , "<div id=\"swagger-ui\"></div>"
  , "<script src=\"https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js\"></script>"
  , "<script>SwaggerUIBundle({url:'/docs/swagger.json',dom_id:'#swagger-ui'})</script>"
  , "</body></html>"
  ]

docsApp :: Application
docsApp req send = case pathInfo req of
  ["docs"]               -> send $ responseLBS status200 [("Content-Type", "text/html")] swaggerHtml
  ["docs", ""]           -> send $ responseLBS status200 [("Content-Type", "text/html")] swaggerHtml
  ["docs", "swagger.json"] -> send $ responseLBS status200 [("Content-Type", "application/json")] swaggerJson
  _                      -> send $ responseLBS status404 [("Content-Type", "application/json")] "{\"error\":\"Not found\"}"
