var map = null;
var geocoder = null;
var marker = null;
var directionsService = null;
var directionsRender = null;
var markers = [];
function initialize() {
    geocoder = new google.maps.Geocoder();
    directionsService = new google.maps.DirectionsService();
}

function initialize_map(pnt) {
    $("#map_canvas").css({display:"block"});
    var myOptions = {
        zoom: 15,
        center: pnt,
        mapTypeId: google.maps.MapTypeId.ROADMAP,
        disableDoubleClickZoom: true,
    };

    map = new google.maps.Map(document.getElementById("map_canvas"), myOptions);
    google.maps.event.addListener(map, "dblclick", function(point) {
        add_waypoint( point.latLng );
    });
    var rendererOptions = {
        map: map,
        preserveViewport: true,
        suppressMarkers: true
    }
    directionsRender = new google.maps.DirectionsRenderer(rendererOptions)

}

function setDirections( result ) {
    var pnts = []
    result.routes[0].overview_path.forEach( function( pnt ) {
        pnts.push( pnt.lat().toFixed(6) + "," + pnt.lng().toFixed(6) );
    });
    $("#directions").val( pnts.join( "|" ) );
}

function setDistance( result ) {
    var dist = 0;
    result.routes[0].legs.forEach( function( leg ) {
        dist += leg.distance.value
    });
    $("#distance").val( dist );
}

function putMarkers( ) {
    var wps = get_waypoint_array();
    //Get rid of old markers
    while( markers.length > 0 ){
        var mkr = markers.pop();
        mkr.setMap( null );
    }
    for( var ii = 0; ii < wps.length; ii++ ) {
        markeropts = {
            draggable: true,
            position: wps[ii],
            map: map
        }
        var mkr = new google.maps.Marker( markeropts );
        google.maps.event.addListener( mkr, "dragend", (function(ii) { 
            return function( point ){
            set_waypoint_i( ii, point.latLng );
            };
        })( ii ) );
        markers.push( mkr );
    }

}

function afterDirectionsLoad(result, status) {
    if (status == google.maps.DirectionsStatus.OK) {
        directionsRender.setMap( map );
        directionsRender.setDirections(result);

        setDirections( result );
        setDistance( result );
        
        putMarkers( );
    }
}


function new_start( ) {
    $("#startErr").empty();
    start = $("#start").val();
    if( !start ) {
        $("#startErr").append( "Address required" );
        return;
    }

    geocoder.geocode( {address: start} , function( results, status ) {
        var point = results[0].geometry.location;
        if( !point ) {
            $("#startErr").append( "Address not found" );
            return;
        }
        if( !map ) {
            initialize_map( point );
        }
        map.setCenter(point);
        map.setZoom(15);
        if( !marker ){
            marker = new google.maps.Marker( { position: point, map: map } );
        } else {
            marker.setLocation( point );
        }
        

        $("#start_lat").val( point.lat() );
        $('#start_lng').val( point.lng() );

        directionsRender.setMap( null );
	$(window).scrollTop( $("#map_canvas").offset().top );
    });
}

function set_waypoint_i( i, point ) {
	var wps = get_waypoint_array();
	wps[i] = point;
	set_waypoint_array( wps );
	
	redraw_directions();
}

function add_waypoint( point ) {
	var wps = get_waypoint_array();
	wps.push( point );
	set_waypoint_array( wps );
	
    redraw_directions();
}

function set_waypoint_array(wps) {
	var wp_strs = $.map( wps, function( point ) {
		return point.lat() + ";" + point.lng();
	});
	$("#waypoints").val( wp_strs.join(":") );
}

function get_waypoint_array() {
	if( $("#waypoints").val() == "" ) {
		return [];
	}
	
	var wps = [];
    $.each( $("#waypoints").val().split(":"), function(){
        var sp = this.split(';');
        wps.push( new google.maps.LatLng( sp[0], sp[1] ) );
    });
	return wps;
}


function redraw_directions( ) {
    var wps = get_waypoint_array();
    if( wps.length > 0 ) {
        wps.unshift( new google.maps.LatLng( $("#start_lat").val(), $("#start_lng").val() ) );
        draw_directions( wps );
    }
}

function draw_directions( wps ) {
    var my_wps = $.map( wps, function( w ) { return w; } );
    var start = my_wps.shift();
    var end = my_wps.pop();
    var request = {
        optimizeWaypoints: false,
        origin: start,
        destination: end,
        travelMode: google.maps.DirectionsTravelMode.WALKING,
        waypoints: $.map( my_wps, function( point ) {
            return { location: point };
        }) };
    directionsService.route( request, afterDirectionsLoad );
}
