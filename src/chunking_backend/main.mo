import Types "types";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import { now } "mo:base/Time";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import List "mo:base/List";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Error "mo:base/Error";

actor Assets {
  private var nextChunkID : Nat = 0;
  private let chunks : HashMap.HashMap<Nat, Types.Chunk> = HashMap.HashMap<Nat, Types.Chunk>(0, Nat.equal, Hash.hash);
  private let assets : HashMap.HashMap<Text, Types.Assets> = HashMap.HashMap<Text, Types.Assets>(0, Text.equal, Text.hash);

  public shared ({ caller }) func create_Chunk(chunk : Types.Chunk) : async {
    chunkId : Nat;
    
  } {
    nextChunkID := nextChunkID + 1;
    chunks.put(nextChunkID, chunk);
    return { chunkId = nextChunkID };
  };
  public shared query ({ caller }) func http_request(request : Types.HttpRequest) : async Types.HttpResponse {
    if (request.method == "get") {
      let split : Iter.Iter<Text> = Text.split(request.url, #char '?');
      let key : Text = Iter.toArray(split)[0];
      let asset : ?Types.Assets = assets.get(key);
      switch (asset) {
        case (?{ content_type : Text; encoding : Types.AssetEncoding }) {
          return {
            body = encoding.content_chunks[0];
            headers = [
              ("Content-Type", content_type),
              ("accept-ranges", "bytes"),
              ("cache-control", "private,max-age=0"),
            ];
            status_code = 200;
            streaming_stategy = create_strategy(key, 0, { content_type; encoding }, encoding);
          };
        };
        case (null) {};
      };
    };
    return {
      body = Blob.toArray(Text.encodeUtf8("Premission Denied. could not pefrom this operation"));
      headers = [];
      status_code = 403;
      streaming_stategy = null;
    };
  };
  private func create_strategy(key : Text, index : Nat, asset : Types.Assets, encoding : Types.AssetEncoding) : ?Types.StreamingStrategy {
    switch (create_token(key, index, encoding)) {
      case (null) { null };
      case (?token) {
        let self : Principal = Principal.fromActor(Assets);
        let canisterId : Text = Principal.toText(self);
        let canister = actor (canisterId) : actor {
          http_request_streaming_callback : shared () -> async ();
        };
        return ? #Callback({
          token;
          callback = canister.http_request_streaming_callback;
        });
      };
    };
  };
  public shared query ({ caller }) func http_request_streaming_callback(st : Types.StreamingCallbackToken) : async Types.StreamingCallbackHttpResponse {
    switch (assets.get(st.key)) {
      case (null) throw Error.reject("Key not found:  " # st.key);
      case (?asset) {
        return {
          token = create_token(
            st.key,
            st.index,
            asset.encoding,
          );
          body = asset.encoding.content_chunks[st.index];
        };
      };
    };
  };
  private func create_token(key : Text, chunk_index : Nat, encoding : Types.AssetEncoding) : ?Types.StreamingCallbackToken {
    if (chunk_index + 1 >= encoding.content_chunks.size()) { null } else {
      ?{
        key;
        index = chunk_index + 1;
        content_encoding = "gzip";
      };
    };
  };

  public shared func commit_batch(
    { batch_name : Text; chunk_ids : [Nat]; content_type : Text } : {
      batch_name : Text;
      content_type : Text;
      chunk_ids : [Nat];
    }
  ) : async () {
    var content_chunks : [[Nat8]] = [];
    for (chunk_id in chunk_ids.vals()) {
      let chunk : ?Types.Chunk = chunks.get(chunk_id);
      switch (chunk) {
        case (?{ content }) {
          content_chunks := Array.append<[Nat8]>(content_chunks, [content]);
        };
        case (null) {};
      };
    };
    if (content_chunks.size() > 0) {
      var total_length = 0;
      for (chunk in content_chunks.vals()) total_length += chunk.size();

      assets.put(
        Text.concat("/assets/", batch_name),
        {
          content_type = content_type;
          encoding = {
            modified = now();
            content_chunks;
            certified = false;
            total_length;
          };
        },
      );
    };
  };
};
