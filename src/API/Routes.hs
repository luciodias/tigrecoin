{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module API.Routes (API, api) where

import Servant ((:>), (:<|>)(..), Proxy(..))
import Servant.API.Experimental.Auth (AuthProtect)

import API.Auth (AuthAPI)
import API.User (UserAPI)
import API.Wallet (WalletAPI)
import API.Transaction (TransactionAPI)

type API =
  "api" :> (
       (AuthProtect "jwt-auth" :> (UserAPI :<|> WalletAPI :<|> TransactionAPI))
  :<|> AuthAPI
  )

api :: Proxy API
api = Proxy
