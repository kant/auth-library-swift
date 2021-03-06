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
import Dispatch
import SwiftyJSON

public class GoogleTokenProvider: TokenProvider {

  public var token: Token?

  public init() throws {
    refresh()
  }

  public func refresh() {
    let sem = DispatchSemaphore(value: 0)
    let urlString = "http://metadata/computeMetadata/v1/instance/service-accounts/default/token"
    let urlComponents = URLComponents(string:urlString)!
    var request = URLRequest(url: urlComponents.url!)
    request.setValue("Google", forHTTPHeaderField:"Metadata-Flavor")
    request.httpMethod = "GET"
    var accessToken = ""
    let session = URLSession(configuration: URLSessionConfiguration.default)
    let task: URLSessionDataTask = session.dataTask(with:request) { (data, response, error) -> Void in
      let json = JSON(data:data!)
      accessToken = json["access_token"].string!
      self.token = Token(accessToken:accessToken)
      sem.signal()
    }
    task.resume()
    _ = sem.wait(timeout: DispatchTime.distantFuture)
  }
}
