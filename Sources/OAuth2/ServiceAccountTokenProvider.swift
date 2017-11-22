// Copyright 2017 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

public struct ServiceAccountToken : Decodable {
  let AccessToken : String
  let ExpiresIn : Int
  let TokenType : String
  enum CodingKeys: String, CodingKey {
    case AccessToken = "access_token"
    case ExpiresIn = "expires_in"
    case TokenType = "token_type"
  }
}

struct Credentials : Codable {
  let CredentialType : String
  let ProjectId: String
  let PrivateKeyId: String
  let PrivateKey: String
  let ClientEmail: String
  let ClientID: String
  let AuthURI: String
  let TokenURI: String
  let AuthProviderX509CertURL: String
  let ClientX509CertURL: String
  enum CodingKeys: String, CodingKey {
    case CredentialType = "type"
    case ProjectId = "project_id"
    case PrivateKeyId = "private_key_id"
    case PrivateKey = "private_key"
    case ClientEmail = "client_email"
    case ClientID = "client_id"
    case AuthURI = "auth_uri"
    case TokenURI = "token_uri"
    case AuthProviderX509CertURL = "auth_provider_x509_cert_url"
    case ClientX509CertURL = "client_x509_cert_url"
  }
}

public class ServiceAccountTokenProvider {
  var credentials : Credentials
  var rsaKey : RSAKey

  public init?(credentialsFileName : String) {
    let credentialsURL = URL(fileURLWithPath:credentialsFileName)
    guard let credentialsData = try? Data(contentsOf:credentialsURL, options:[]) else {
      return nil
    }
    let decoder = JSONDecoder()
    guard let credentials = try? decoder.decode(Credentials.self, from: credentialsData)
      else {
        return nil
    }
    self.credentials = credentials
    guard let rsaKey = RSAKey(privateKey:credentials.PrivateKey)
      else {
        return nil
    }
    self.rsaKey = rsaKey
  }

  public func fetchToken(callback:@escaping (ServiceAccountToken?, Error?) -> Void) throws {
    let iat = Date()
    let exp = iat.addingTimeInterval(3600)
    let jwtClaimSet = JWTClaimSet(Issuer:credentials.ClientEmail,
                                  Audience:credentials.TokenURI,
                                  Scope: "https://www.googleapis.com/auth/cloud-platform",
                                  IssuedAt: Int(iat.timeIntervalSince1970),
                                  Expiration: Int(exp.timeIntervalSince1970))
    let jwtHeader = JWTHeader(Algorithm: "RS256",
                              Format: "JWT")
    let msg = try JWT.encodeWithRS256(jwtHeader:jwtHeader,
                                      jwtClaimSet:jwtClaimSet,
                                      rsaKey:rsaKey)
    var urlComponents = URLComponents(string:"")!
    urlComponents.queryItems =
      [URLQueryItem(name:"grant_type",
                    value:"urn:ietf:params:oauth:grant-type:jwt-bearer"),
       URLQueryItem(name:"assertion",
                    value:msg)]
    let query = urlComponents.percentEncodedQuery!

    var urlRequest = URLRequest(url:URL(string:credentials.TokenURI)!)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = query.data(using:.utf8)
    urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type")

    let session = URLSession(configuration: URLSessionConfiguration.default)
    let task: URLSessionDataTask = session.dataTask(with:urlRequest)
    {(data, response, error) -> Void in
      let decoder = JSONDecoder()
      if let data = data,
        let token = try? decoder.decode(ServiceAccountToken.self, from: data) {
        callback(token, error)
      } else {
        callback(nil, error)
      }
    }
    task.resume()
  }
}