{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module App where

import Control.Monad.Reader (runReaderT)
import Network.Wai (Application, pathInfo)
import Servant (ServerT, (:<|>)(..), Context(..), serveWithContextT)
import Servant.Server.Experimental.Auth (mkAuthHandler)

import Auth.Middleware (AuthUser, mkAuthMiddleware)
import API.Routes (API, api)
import API.Auth (authServer)
import API.User (userServer)
import API.Wallet (walletServer)
import API.Transaction (transactionServer)
import API.Swagger (docsApp)
import Config (Env(..))
import Types.AppM (AppM)

mkApp :: Env -> Application
mkApp env =
  let jwtSecret = envJwtSecret env
      authHandler = mkAuthHandler (mkAuthMiddleware jwtSecret)
      context = authHandler :. EmptyContext
      nt appM = runReaderT appM env
      servantApp = serveWithContextT api context nt server
  in \req send -> case pathInfo req of
       ("docs" : _) -> docsApp req send
       _             -> servantApp req send

server :: ServerT API AppM
server =
  ( \authUser ->
       userServer authUser
  :<|> walletServer authUser
  :<|> transactionServer authUser
  )
  :<|> authServer
