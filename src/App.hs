{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module App where

import Control.Monad.Reader (runReaderT)
import Network.Wai (Application)
import Servant ((:>), ServerT, (:<|>)(..), Proxy(..), Context(..), serveWithContextT)
import Servant.API.Experimental.Auth (AuthProtect)
import Servant.Server.Experimental.Auth (AuthHandler, mkAuthHandler)

import Auth.Middleware (AuthUser, mkAuthMiddleware)
import API.Auth (AuthAPI, authServer)
import API.User (UserAPI, userServer)
import API.Wallet (WalletAPI, walletServer)
import API.Transaction (TransactionAPI, transactionServer)
import Config (Env(..))
import Types.AppM (AppM)

type API =
  "api" :> (
       (AuthProtect "jwt-auth" :> (UserAPI :<|> WalletAPI :<|> TransactionAPI))
  :<|> AuthAPI
  )

api :: Proxy API
api = Proxy

mkApp :: Env -> Application
mkApp env =
  let jwtSecret = envJwtSecret env
      authHandler = mkAuthHandler (mkAuthMiddleware jwtSecret)
      context = authHandler :. EmptyContext
      nt appM = runReaderT appM env
  in serveWithContextT api context nt server

server :: ServerT API AppM
server =
  ( \authUser ->
       userServer authUser
  :<|> walletServer authUser
  :<|> transactionServer authUser
  )
  :<|> authServer
