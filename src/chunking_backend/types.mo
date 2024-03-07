module {
    public type HeaderField = (Text, Text);
    public type Chunk = {
        batch_name : Text;
        content : [Nat8];
    };
    public type Assets = {
        content_type : Text;
        encoding : AssetEncoding;
    };
    public type AssetEncoding = {

        modified : Int;
        content_chunks : [[Nat8]];
        certified : Bool;
        total_length : Nat;

    };
    public type HttpRequest = {
        url : Text;
        method : Text;
        body : [Nat8];
        headers : [HeaderField];
    };
    public type HttpResponse = {
        body : [Nat8];
        headers : [HeaderField];
        status_code : Nat16;
        streaming_stategy : ?StreamingStrategy;
    };
    public type StreamingCallbackToken = {
        key : Text;
        content_encoding : Text;
        index : Nat; //starts at 1
    };

    public type StreamingStrategy = {
        #Callback : {
            token : StreamingCallbackToken;
            callback : shared () -> async ();
        };
    };

    public type StreamingCallbackHttpResponse = {
        token : ?StreamingCallbackToken;
        body : [Nat8];
    };

};
