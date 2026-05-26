{-# LANGUAGE OverloadedStrings #-}

module API.AuthSpec (spec) where

import Data.Aeson (object, (.=))
import Helper

import qualified Data.ByteString.Char8 as C
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T

spec = before_ cleanDb $ do
  describe "methodPost /api/auth/register" $ do
    it "creates a new user and returns 204" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      liftIO $ C.length token `shouldSatisfy` (> 0)

    it "rejects duplicate email with 409" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      request methodPost "/api/auth/register"
        [("Content-Type", "application/json")]
        (encodeStrict $ object
          [ "name"     .= ("Alice" :: T.Text)
          , "email"    .= ("alice@test.com" :: T.Text)
          , "password" .= ("secret123" :: T.Text)
          ])
        `shouldRespondWith` 409

    it "rejects missing fields with 4xx" $ do
      let body = encodeStrict $ object
            [ "name" .= ("Bob" :: T.Text) ]
      request methodPost "/api/auth/register"
        [("Content-Type", "application/json")] body
        `shouldRespondWith` 422

  describe "methodPost /api/auth/login" $ do
    it "succeeds with valid credentials" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      token <- loginUser ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      liftIO $ C.length token `shouldSatisfy` (> 0)

    it "rejects wrong password with 401" $ do
      registerUser ("Alice" :: T.Text) ("alice@test.com" :: T.Text) ("secret123" :: T.Text)
      request methodPost "/api/auth/login"
        [("Content-Type", "application/json")]
        (encodeStrict $ object
          [ "email"    .= ("alice@test.com" :: T.Text)
          , "password" .= ("wrongpass" :: T.Text)
          ])
        `shouldRespondWith` 401

    it "rejects non-existent email with 401" $ do
      request methodPost "/api/auth/login"
        [("Content-Type", "application/json")]
        (encodeStrict $ object
          [ "email"    .= ("nobody@test.com" :: T.Text)
          , "password" .= ("password" :: T.Text)
          ])
        `shouldRespondWith` 401
