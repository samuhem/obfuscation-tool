% Class containing source code for obfuscation work done in association
% with Benchmark project.
%
% Please see README for instructions.
%
% Author: S. Hemminki
% Date 08.03.2021
% 
% -------------------------------------------------------------------------
% LICENSE
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS 
% OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF 
% OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
%
% -------------------------------------------------------------------------
%
% This class uses external function for plotting on google maps: 
% plot_google_maps
%  http://www.mathworks.com/matlabcentral/fileexchange/24113
%  http://www.maptiler.org/google-maps-coordinates-tile-bounds-projection/
%  http://developers.google.com/maps/documentation/staticmaps/
%

classdef Obfuscation
    
    % VARIABLES
    properties
        
        % Database connection for loading data
        indb_datasource                          = "";
        indb_username                            = "";
        indb_password                            = "";
        
        % Database connection for exporting data
        outdb_datasource                         = "";
        outdb_username                           = "";
        outdb_password                           = "";
        
        % Temporal obfuscation, applies to all timestamp fields:
        % 0: Precise times, 
        % 1: Hourly, 
        % 2: AM/PM, 
        % 3: Date
        obfuscate_temporal_granularity          = 1; 
        
        % Level of obfuscation for sensitive travels
        obf_minDist_between_waypoints_m         = 500;
        obf_minDuration_between_waypoints_ms    = 6 * 60 * 1000;
        
        % Query Parameters
        use_caching_for_OAQueries               = 1;  % Boolean
        query_start_ts                          = []; % Epoch ms
        query_end_ts                            = []; % Epoch ms
        
        % OutputAreas local cache directory
        OAQuery_cacheDir                        = "";
        
        % Figure handling
        figureName                              = 'fig_anonymizer';
        figureName_gmap                         = 'fig_anongmap';
        figure_pos_size                         = [100 100 800 600];
        
        % User ID
        user                                    = [];
        
        % Holder for DB connection
        db_conn                                 = [];
        
        % DB tables
        tbl_routes                              = [];
        tbl_legs                                = [];
        tbl_places                              = [];
        tbl_dwells                              = [];
        tbl_waypoints                           = [];
        tbl_revgeo                              = [];
        
        % Anonymization
        protectedAreas                          = [];
        
    end
    
    % CONSTANTS
    properties (Constant)
        
        % Temporal obfuscation levels
        OBF_NONE            = 0;
        OBF_HOUR            = 1;
        OBF_AMPM            = 2;
        OBF_DATE            = 3;
        
        % PrivacyIDs
        privacy_unknown     = 0;
        privacy_public      = 1;
        privacy_sensitive   = 2;
        privacy_private     = 3;
        
        % Mode IDS
        MODEID_UNKNOWN      = 0;
        MODEID_TILTING      = 1;
        MODEID_STATIONARY   = 2;
        MODEID_WALK         = 3;
        MODEID_RUN          = 4;
        MODEID_BIKE         = 5;
        MODEID_AUTOMOTIVE   = 6;
        MODEID_BUS          = 7;
        MODEID_TRAIN        = 8;
        MODEID_TRAM         = 9;
        MODEID_METRO        = 10;
        MODEID_CAR          = 11;
        MODEID_BOAT         = 12;
        MODEID_AERIAL       = 13;
        MODEID_PUBLICTRANS  = 14;
        
        MODES_PUBLICTRANSIT = [7,8,9,10,12,13,16];
        
        % Mode ColorCodes as hex
        COLOUR_DEFAULT      = '#FF0000';
        COLOUR_STATIONARY   = '#646464';
        COLOUR_WALK         = '#00fe00';
        COLOUR_RUN          = '#00fe00';
        COLOUR_BICYCLE      = '#0000fe';
        COLOUR_AUTOMOTIVE   = '#fe0000';
        COLOUR_BUS          = '#fefe00';
        COLOUR_CAR          = '#fe0000';
        COLOUR_TRAIN        = '#00fefe';
        COLOUR_TRAM         = '#00fefe';
        COLOUR_METRO        = '#c65ffe';
        COLOUR_BOAT         = '#b2dafe';
        COLOUR_AERIAL       = '#0064fa';
        
        % SQL STATEMENTS
        
        sql_rgeo_by_id    = ...
            strcat("SELECT * FROM reverse_geocode ",        ...
            "WHERE installation_id like ");
        
        sql_routes_by_id =                                  ...
            strcat("SELECT * FROM routes ",                 ...
            "WHERE obsolete = false AND installation_id like ");
        
        sql_legs_by_id =                                    ...
            strcat("SELECT *, ",                            ...
            "st_x(first_location) as firstloc_lat, ",       ...
            "st_y(first_location) as firstloc_lon, ",       ...
            "FROM legs WHERE obsolete = false and ",    ...
            "installation_id like ");
        
        sql_waypoints_by_id = ...
            strcat("SELECT *, st_x(location) as lat, ",     ...
            "st_y(location) as lon, FROM waypoints ",       ...
            "WHERE installation_id like ");
        
        sql_places_by_id = ...
            strcat("SELECT *, st_x(location) as lat, ",     ...
            "st_y(location) as lon FROM places ",           ...
            "WHERE installation_id like ");
        
        sql_dwells_by_id = ...
            strcat("SELECT *, st_x(location) lat, ",        ...
            "st_y(location) lon, FROM dwells ",             ...
            "WHERE obsolete = false AND installation_id like ");
        
        warning_structOnObject = 'MATLAB:structOnObject';
        
    end
    
    % PUBLIC METHODS
    methods
        
        % CONSTRUCTOR
        function obj = Obfuscation()
        end
         
        % Run entire anonymization pipeline for input user
        function obj = run(obj, user)
            
            if nargin < 2
                disp('Missing user installationID');
                return;
            end
            
            % Close any existing connection
            if ~isempty(obj.db_conn)
                obj.db_conn.close;
            end
            
            % Connect to input DB
            obj = obj.connectToInputDB;
            
            % Load user
            obj = obj.loadUser(user);
            
            % Associate Places with Lower level Output Areas (LLOAs)
            obj = obj.mapPlacesToOutputAreas;
            
            % Create protectedAreas with polygons from LSOAs
            obj = obj.buildProtectedAreas;
            
            % Hide private waypoints
            obj = obj.hidePrivateWaypoints;
            
            % Hide sensitive information related to Places 
            obj = obj.obfuscatePlaces();
            
            % Hide sensitive information related to Routes
            obj = obj.obfuscateTravelsWithProtectedAreas();
            
            % Reduce granularity of legs based on their sensitivity
            obj = obj.obfuscateTravelsWithTravelSensitivity();
            
            % Reduce temporal granularity based on user options
            obj = obj.obfuscateTemporal();
            
            % Connect to output DB
            obj = obj.connectToOutputDB();
            
            % Push processed data to output DB
            obj = obj.pushObfuscatedData();
            
        end
        
        % Connect to input database
        function obj = connectToInputDB(obj)
            
            if ~isempty(obj.db_conn)
                obj.closeDB;
            end
            
            obj.db_conn = database(obj.indb_datasource, obj.indb_username, obj.indb_password);
            
            disp(['Connecting to input database...']);
            if isempty(obj.db_conn.Message)
                disp(['OK.']);
            else
                disp(obj.db_conn.Message)
            end
            
        end
        
        % Connect to output database
        function obj = connectToOutputDB(obj)
            
            if ~isempty(obj.db_conn)
                obj.closeDB;
            end
            
            obj.db_conn = database(obj.outdb_datasource, obj.outdb_username, obj.outdb_password);
            
            disp(['Connecting to output database...']);
            if isempty(obj.db_conn.Message)
                disp(['OK.']);
            else
                disp(obj.db_conn.Message)
            end
        end
        
        % Close connection to database
        function obj = closeDB(obj)
            if ~isempty(obj.db_conn)
                obj.db_conn.close;
            end
        end
        
        % Set start and end timestamps as epoch milliseconds for querying data
        function obj = setQueryTS(obj, start_ts, end_ts)
            obj.query_start_ts = start_ts;
            obj.query_end_ts   = end_ts;
        end
        
        % Query data for input installationId
        function obj = loadUser(obj, installationId)
            
            orderByStartTS = " ORDER BY start_ts asc";
            orderByTS      = " ORDER BY timestamp asc";
            
            if ~isempty(obj.query_start_ts) && ~isempty(obj.query_end_ts)
                dateRangeStartEndTS = strcat(" AND start_ts >= ", num2str(obj.query_start_ts), " AND end_ts <= ", num2str(obj.query_end_ts));
            else
                dateRangeStartEndTS = "";
            end
            
            if ~isempty(obj.query_start_ts) && ~isempty(obj.query_end_ts)
                dateRangeTS = strcat(" AND timestamp >= ", num2str(obj.query_start_ts), " AND timestamp <= ", num2str(obj.query_end_ts));
            else
                dateRangeTS = "";
            end
            
            disp(['Loading user data from input database...']);
            
            % Prepare SQL queries
            sql_places    = strcat(obj.sql_places_by_id, installationId);
            sql_routes    = strcat(obj.sql_routes_by_id, installationId, dateRangeStartEndTS, orderByStartTS);
            sql_legs      = strcat(obj.sql_legs_by_id, installationId, dateRangeStartEndTS, orderByStartTS);
            sql_dwells    = strcat(obj.sql_dwells_by_id, installationId, dateRangeStartEndTS, orderByStartTS);
            sql_waypoints = strcat(obj.sql_waypoints_by_id, installationId, dateRangeTS, orderByTS);
            sql_revgeo    = strcat(obj.sql_rgeo_by_id, installationId);
            
            obj.tbl_legs                    = obj.executeSQL(sql_legs);
            obj.tbl_routes                  = obj.executeSQL(sql_routes);
            obj.tbl_waypoints               = obj.executeSQL(sql_waypoints);
            obj.tbl_places                  = obj.executeSQL(sql_places);
            obj.tbl_dwells                  = obj.executeSQL(sql_dwells);
            obj.tbl_revgeo                  = obj.executeSQL(sql_revgeo);
            
            % String -> numeric
            obj                         = obj.tmodes2integers();
            obj                         = obj.providers2integers();
            
            % Initialise fields for obfuscation
            obj                         = obj.initialiseObfuscation();
        end
        
        % Initialize fields for hidden/obfuscated information
        function obj = initialiseObfuscation(obj)
            
            % Initialize fields for anonymization of waypoints
            n                                   = size(obj.tbl_waypoints, 1);
            v                                   = repmat(-1, n, 1);
            obj.tbl_waypoints.privacy           = zeros(n,1);
            obj.tbl_waypoints.hidden            = zeros(n,1);
            obj.tbl_waypoints.hidden_lat        = v;
            obj.tbl_waypoints.hidden_lon        = v;
            obj.tbl_waypoints.hidden_ts         = v;
            obj.tbl_waypoints.hidden_speed      = v;
            obj.tbl_waypoints.hidden_acc        = v;
            obj.tbl_waypoints.hidden_vacc       = v;
            obj.tbl_waypoints.hidden_provider   = v;
            obj.tbl_waypoints.hidden_tzoffset   = v;
            
            % Initialize fields for anonymization of routes
            n                                   = size(obj.tbl_routes, 1);
            v                                   = repmat(-1, n, 1);
            obj.tbl_routes.privacy              = zeros(n,1);
            obj.tbl_routes.hidden               = zeros(n,1);
            obj.tbl_routes.hidden_start_ts      = v;
            obj.tbl_routes.hidden_end_ts        = v;
            obj.tbl_routes.hidden_duration      = v;
            obj.tbl_routes.hidden_distance      = v;
            obj.tbl_routes.hidden_gis_distance  = v;
            
            % Initialize fields for anonymization of legs
            n                                = size(obj.tbl_legs, 1);
            v                                = repmat(-1, n, 1);
            obj.tbl_legs.privacy             = zeros(n,1);
            obj.tbl_legs.hidden              = zeros(n,1);
            obj.tbl_legs.hidden_start_ts     = v;
            obj.tbl_legs.hidden_end_ts       = v;
            obj.tbl_legs.hidden_firstloc_lat = v;
            obj.tbl_legs.hidden_firstloc_lon = v;
            obj.tbl_legs.hidden_lastloc_lat  = v;
            obj.tbl_legs.hidden_lastloc_lon  = v;
            obj.tbl_legs.hidden_duration     = v;
            obj.tbl_legs.hidden_distance     = v;
            
            % Initialize fields for anonymization of dwells
            n                               = size(obj.tbl_dwells, 1);
            v                               = repmat(-1, n, 1);
            obj.tbl_dwells.privacy          = zeros(n,1);
            obj.tbl_dwells.hidden           = zeros(n,1);
            obj.tbl_dwells.hidden_start_ts  = v;
            obj.tbl_dwells.hidden_end_ts    = v;
            obj.tbl_dwells.hidden_duration  = v;
            
            % Initialize fields for anonymization of places
            n                                   = size(obj.tbl_places, 1);
            v                                   = repmat(-1, n, 1);
            obj.tbl_places.hidden               = zeros(n,1);
            obj.tbl_places.hidden_lat           = v;
            obj.tbl_places.hidden_lon           = v;
            obj.tbl_places.hidden_timestamp     = v;
            obj.tbl_places.hidden_first_dwellTS = v;
            obj.tbl_places.hidden_last_dwellTS  = v;
            
            % Initialize fields for anonymization of revgeo
            n                                   = size(obj.tbl_revgeo, 1);
            obj.tbl_revgeo.privacy              = zeros(n,1);
            obj.tbl_revgeo.hidden               = zeros(n,1);
            obj.tbl_revgeo.match_location       = [];
            obj.tbl_revgeo.source_location      = [];
            obj.tbl_revgeo.match_distance       = [];
            
        end
        
        % Map Places stored in this obj to OutputAreas
        function obj = mapPlacesToOutputAreas(obj)
            
            nPlaces = size(obj.tbl_places, 1);
            
            % obj.initFigure();
            % hold on;
            
            % Query from Office of National Statistics (UK)
            obj.tbl_places.area = cell(nPlaces,1);
            for i = 1:nPlaces
                
                place      = obj.tbl_places(i,:);
                outputArea = obj.queryOutputArea(place.lat, place.lon);
                
                if isfield(outputArea, 'geom')
                    if ~isempty(outputArea.geom)
                        
                        geom_orig = outputArea.geom;
                        if iscell(geom_orig)
                            geom_orig = geom_orig{1};
                        end
                        geom_ps = dpsimplify(geom_orig, 0.00003);
                        outputArea.geom = geom_ps;
                        outputArea.place_id = place.id;
                        obj.tbl_places(i,:).area = {outputArea};
                        
                        % plot(geom_ps(:,1),geom_ps(:,2))
                        % plot(place.lon, place.lat, '*')
                        % pause;
                    end
                end
            end
        end
        
        % Build protected areas based on place privacy_sensitivity
        function obj = buildProtectedAreas(obj)
            
            places = obj.tbl_places;
            
            j = 1;
            for i=1:size(places,1)
                
                place = places(i,:);
                
                if ~isempty(place.area{1})
                    
                    geom                          = place.area{1}.geom;
                    pgon                          = polyshape(geom(:,1),geom(:,2));
                    [centroidLon, centroidLat]    = pgon.centroid;
                    obj.protectedAreas(j).geo     = [centroidLon, centroidLat];
                    obj.protectedAreas(j).pgon    = pgon;
                    obj.protectedAreas(j).name    = place.area{1}.name;
                    obj.protectedAreas(j).place   = place.id;
                    obj.protectedAreas(j).maxLon  = max(geom(:,1));
                    obj.protectedAreas(j).maxLat  = max(geom(:,2));
                    obj.protectedAreas(j).minLon  = min(geom(:,1));
                    obj.protectedAreas(j).minLat  = min(geom(:,2));
                    obj.protectedAreas(j).privacy = place.privacy_sensitivity;
                    
                    % Set as protected area for the place
                    obj.tbl_places.area(i)        = {obj.protectedAreas(j)};
                    
                    j = j + 1;
                end
            end
        end
        
        % Hide private (=privacy level 3) waypoints
        function obj = hidePrivateWaypoints(obj)
            % Find level 3 protected areas (= private areas)
            privateAreas = [];
            for i = 1 : length(obj.protectedAreas)
                if obj.protectedAreas(i).privacy == 3
                    if isempty(privateAreas)
                        privateAreas = obj.protectedAreas(i);
                    else
                        privateAreas(end + 1) = obj.protectedAreas(i);
                    end
                    
                end
            end
            
            obj.tbl_waypoints = obj.hideSensitiveWaypointsInPAs(obj.tbl_waypoints, privateAreas, 1);
            
        end
        
        % Obfuscate data belonging to a place indicated by input id
        function obj = obfuscatePlaces(obj, ids)
            
            if nargin < 2
                ids = obj.tbl_places.id;
            end
            
            for ii = 1 : length(ids)
                
                id = ids(ii);
                
                place  = obj.getPlaceByID(id);
                
                % Update Places
                if place.privacy_sensitivity > 1
                    place.hidden = 1;
                    if ~isempty(place.area{1})
                        place.hidden_lat = place.area{1}.geo(2);
                        place.hidden_lon = place.area{1}.geo(1);
                    end
                end
                obj = obj.updatePlace(place);
                
                % Updated dwells
                dwells = obj.getDwellsForPlace(place.id);
                for i = 1 : size(dwells, 1)
                    
                    dwellDurationType = obj.getDwellDurationType(dwells(i,:));
                    
                    if dwellDurationType == 4
                        dwells(i,:).privacy = 3;
                    else
                        dwells(i,:).privacy = place.privacy_sensitivity;
                    end
                    
                    if dwells(i,:).privacy == 3
                        dwells(i,:).hidden = 1;
                        continue;
                    end
                    
                    if dwells(i,:).privacy == 2
                        dwells(i,:).hidden = 1;
                        dwells(i,:).hidden_duration = dwellDurationType;
                    end
                end
                obj = obj.updateDwells(dwells);
                
                % Update reverse geocode
                rgeo = obj.getReverseGeocodeForPlace(place.id);
                
                if isempty(rgeo)
                    continue;
                end
                
                rgeo.privacy = place.privacy_sensitivity;
                if place.privacy_sensitivity > 1
                    rgeo.district        = {[]};
                    rgeo.street          = {[]};
                    rgeo.housenumber     = -1;
                    rgeo.postalcode      = {[]};
                end
                
                obj = obj.updateRGeos(rgeo); 
            end
            
        end
        
        % Obfuscate travel data based on Place PAs
        function obj = obfuscateTravelsWithProtectedAreas(obj, ids)
            
            if nargin < 2
                ids = obj.tbl_routes.id;
            end
            
            for ii = 1 : length(ids)
                
                id = ids(ii);
                
                route    = obj.getRouteByID(id);
                routeWPs = obj.getWaypointsForRoute(id);
                
                % No waypoints for route; don't do anything (for now)
                if isempty(routeWPs)
                    continue;
                end
                
                % Handle waypoints in startPlace protected area
                startPlace = obj.getPlaceByID(route.start_place);
                
                if ~isempty(startPlace) && startPlace.privacy_sensitivity > 1
                    obfWPs = obj.hideSensitiveWaypointsInPAs(routeWPs, startPlace.area, 0);
                    
                    % Set timestamps to first un-obfuscated waypoint
                    prevPublicWP = [];
                    i_firstHidden = -1;
                    for i = size(obfWPs,1) : -1 : 1
                        
                        if obfWPs.hidden(i) == 1 && ~isempty(prevPublicWP)
                            obfWPs.hidden_ts(i)         = prevPublicWP.timestamp;
                            obfWPs.hidden_lat(i)        = prevPublicWP.lat;
                            obfWPs.hidden_lon(i)        = prevPublicWP.lon;
                            obfWPs.hidden_speed(i)      = -1;
                            obfWPs.hidden_acc(i)        = -1;
                            obfWPs.hidden_vacc(i)       = -1;
                            obfWPs.hidden_provider(i)   = -1;
                            obfWPs.hidden_tzoffset(i)   = obfWPs.timezone_offset(i);  
                            i_firstHidden               = i;
                        else
                            prevPublicWP = obfWPs(i,:);
                        end
                    end
                    
                    % Set first waypoint to start from protected area centroid
                    if i_firstHidden > 0 && ~isempty(startPlace.area)
                        obfWPs.hidden_lat(i_firstHidden) = startPlace.area{1}.geo(2);
                        obfWPs.hidden_lon(i_firstHidden) = startPlace.area{1}.geo(1);
                    end
                    
                    obj = obj.updateWaypoints(obfWPs(obfWPs.hidden == 1,:));
                end
                
                % Handle waypoints in endPlace protected area
                endPlace = obj.getPlaceByID(route.end_place);
                
                if ~isempty(endPlace) && endPlace.privacy_sensitivity > 1
                    obfWPs = obj.hideSensitiveWaypointsInPAs(routeWPs, endPlace.area, 0);
                    
                    % Set timestamps to last un-obfuscated waypoint
                    prevPublicWP = [];
                    i_lastHidden = -1;
                    for i = 1 : size(obfWPs,1)
                        if obfWPs.hidden(i) == 1 && ~isempty(prevPublicWP)
                            obfWPs.hidden_ts(i)         = prevPublicWP.timestamp;
                            obfWPs.hidden_lat(i)        = prevPublicWP.lat;
                            obfWPs.hidden_lon(i)        = prevPublicWP.lon;
                            obfWPs.hidden_speed(i)      = -1;
                            obfWPs.hidden_acc(i)        = -1;
                            obfWPs.hidden_vacc(i)       = -1;
                            obfWPs.hidden_provider(i)   = -1;
                            obfWPs.hidden_tzoffset(i)   = obfWPs.timezone_offset(i);  
                            i_lastHidden                = i;
                        else
                            prevPublicWP = obfWPs(i,:);
                        end
                    end
                    
                    % Set last waypoint to end to protected area centroid
                    if i_lastHidden > 0 && ~isempty(endPlace.area)
                        obfWPs.hidden_lat(i_lastHidden) = endPlace.area{1}.geo(2);
                        obfWPs.hidden_lon(i_lastHidden) = endPlace.area{1}.geo(1);
                    end
                    
                    obj = obj.updateWaypoints(obfWPs(obfWPs.hidden == 1,:));
                end
                
                % Update Route fields
                routeWPs  = obj.getWaypointsForRoute(id);
                i_firstWP = find(routeWPs.hidden ~= 1, 1, 'first');
                i_lastWP  = find(routeWPs.hidden ~= 1, 1, 'last');
                
                % No visible waypoints; the whole route is hidden
                if isempty(i_firstWP)
                    route.hidden          = 1;
                    route.privacy         = 3;
                    route.hidden_start_ts = routeWPs.hidden_ts(1);
                    route.hidden_end_ts   = routeWPs.hidden_ts(end);
                    route.hidden_duration = 0;
                    route.hidden_distance = 0;
                else
                    % No hidden waypoints, whole route is visible
                    if i_firstWP == 1 && i_lastWP == size(routeWPs, 1) % '1' as second parameter calculates distance without hidden points
                        route.privacy = 1;
                        route.hidden  = 0;
                    
                    % Partially hidden  
                    else
                        obfDistance = obj.getWaypointsDistance(routeWPs, 1);
                        obfStartTS  = min(routeWPs.timestamp(routeWPs.hidden ~= 1));
                        obfEndTS    = max(routeWPs.timestamp(routeWPs.hidden ~= 1));
                        obfDuration = obfEndTS - obfStartTS;
                        
                        route.hidden               = 1;
                        route.privacy              = 2;
                        route.hidden_start_ts      = obfStartTS;
                        route.hidden_end_ts        = obfEndTS;
                        route.hidden_distance      = obfDistance;
                        route.hidden_duration      = obfDuration;
                    end
                end
                
                obj = obj.updateRoutes(route);
                
                % Update leg fields
                legs = obj.getLegsByRouteID(route.id);
                
                for i = 1 : size(legs,1)
                    
                    legWPs = obj.getWaypointsForLeg(legs.id(i));
                    
                    if isempty(legWPs)
                        continue;
                    end
                    
                    i_firstWP   = find(legWPs.hidden ~= 1, 1, 'first');
                    i_lastWP    = find(legWPs.hidden ~= 1, 1, 'last');
                    
                    % No visible waypoints; the whole leg is hidden
                    if isempty(i_firstWP)
                        legs(i,:).privacy              = 3;
                        legs(i,:).hidden               = 1;
                        legs(i,:).hidden_start_ts      = legWPs(1,:).hidden_ts;
                        legs(i,:).hidden_end_ts        = legWPs(end,:).hidden_ts;
                        legs(i,:).hidden_duration      = 0;
                        legs(i,:).hidden_distance      = 0;
                        legs(i,:).hidden_firstloc_lat  = legWPs(1,:).hidden_lat;
                        legs(i,:).hidden_firstloc_lon  = legWPs(1,:).hidden_lon;
                        legs(i,:).hidden_lastloc_lat   = legWPs(end,:).hidden_lat;
                        legs(i,:).hidden_lastloc_lon   = legWPs(end,:).hidden_lon;
                        continue;
                    end
                    
                    % No hidden waypoints, whole leg is visible
                    if i_firstWP == 1 && i_lastWP == size(legWPs,1)
                        legs(i,:).privacy = 1;
                        legs(i,:).hidden  = 0;
                        continue;
                    end
                    
                    % Partially hidden leg
                    obfDistance = obj.getWaypointsDistance(legWPs, 1);
                    obfStartTS  = min(legWPs.timestamp(legWPs.hidden ~= 1));
                    obfEndTS    = max(legWPs.timestamp(legWPs.hidden ~= 1));
                    obfDuration = obfEndTS - obfStartTS;
                    
                    legs(i,:).hidden               = 1;
                    legs(i,:).privacy              = 2;
                    legs(i,:).hidden_start_ts      = obfStartTS;
                    legs(i,:).hidden_end_ts        = obfEndTS;
                    legs(i,:).hidden_distance      = obfDistance;
                    legs(i,:).hidden_duration      = obfDuration;
                    legs(i,:).hidden_firstloc_lat  = legWPs.lat(i_firstWP);
                    legs(i,:).hidden_firstloc_lon  = legWPs.lon(i_firstWP);
                    legs(i,:).hidden_lastloc_lat   = legWPs.lat(i_lastWP);
                    legs(i,:).hidden_lastloc_lon   = legWPs.lon(i_lastWP);
                    
                end
                
                obj = obj.updateLegs(legs);
                
            end
        end
        
        % Obfuscate travel data based on leg sensitivity
        function obj = obfuscateTravelsWithTravelSensitivity(obj)
            
            legs = obj.tbl_legs;
            
            for i = 1 : size(legs, 1)
                
                gl = legs(i,:);
                privacy = gl.privacy_sensitivity;
                
                % For unknown or nan privacy, assume highest privacy
                if isnan(privacy) || privacy == 0
                    privacy = obj.privacy_public;
                end
                
                % Retain all details for public privacy
                if privacy == obj.privacy_public
                    continue;
                end
                
                wps = obj.getWaypointsForLeg(gl.id);
                
                if isempty(wps)
                    continue;
                end
                
                % Reduce granularity for sensitive privacy
                if privacy == obj.privacy_sensitive
                    if size(wps, 1) > 2
                        
                        prevWP = wps(1,:);
                        
                        if wps.hidden(1) == 1
                            prev_lat = wps.hidden_lat(1);
                            prev_lon = wps.hidden_lon(1);
                        else
                            prev_lat = wps.lat(1);
                            prev_lon = wps.lon(1);
                        end
                        
                        for j = 2 : size(wps, 1)
                            
                            thisWP  = wps(j,:);
                            
                            if thisWP.hidden == 1
                                this_lat = thisWP.hidden_lat;
                                this_lon = thisWP.hidden_lon;
                            else
                                this_lat = thisWP.lat;
                                this_lon = thisWP.lon;
                            end
                            
                            d       = obj.getDistanceBetween([prev_lat, prev_lon], [this_lat, this_lon]);
                            dt      = thisWP.timestamp - prevWP.timestamp;
                            
                            if d > obj.obf_minDist_between_waypoints_m && dt > obj.obf_minDuration_between_waypoints_ms
                                prevWP   = thisWP;
                                prev_lat = this_lat;
                                prev_lon = this_lon;
                            else
                                wps.hidden(j)           = 1;
                                wps.hidden_lat(j)       = prev_lat;
                                wps.hidden_lon(j)       = prev_lon;
                                
                                if prevWP.hidden == 1
                                    wps.hidden_ts(j)        = prevWP.hidden_ts;
                                    wps.hidden_speed(j)     = prevWP.hidden_speed;
                                    wps.hidden_acc(j)       = prevWP.hidden_acc;
                                    wps.hidden_vacc(j)      = prevWP.hidden_vacc;
                                    wps.hidden_provider(j)  = prevWP.hidden_provider;
                                    wps.hidden_tzoffset(j)  = prevWP.hidden_tzoffset;
                                else
                                    wps.hidden_ts(j)        = prevWP.timestamp;
                                    wps.hidden_speed(j)     = prevWP.speed;
                                    wps.hidden_acc(j)       = prevWP.accuracy;
                                    wps.hidden_vacc(j)      = prevWP.vaccuracy;
                                    wps.hidden_provider(j)  = prevWP.provider;
                                    wps.hidden_tzoffset(j)  = prevWP.timezone_offset;
                                end
                            end
                        end
                    end                  
                end
                
                % Retain only start - end points for private privacy
                if privacy == obj.privacy_private
                    
                    if wps.hidden(1) == 1
                        firstLat      = wps.hidden_lat(1);
                        firstLon      = wps.hidden_lon(1);
                        firstTS       = wps.hidden_ts(1);
                        firstSpeed    = wps.hidden_speed(1);
                        firstProv     = wps.hidden_provider(1);
                        firstAcc      = wps.hidden_acc(1);
                        firstVAcc     = wps.hidden_vacc(1);
                        firstTZOffset = wps.hidden_tzoffset(1);
                    else
                        firstLat      = wps.lat(1);
                        firstLon      = wps.lon(1);
                        firstTS       = wps.timestamp(1);
                        firstSpeed    = wps.speed(1); 
                        firstAcc      = wps.accuracy(1); 
                        firstVAcc     = wps.vaccuracy(1); 
                        firstProv     = wps.provider(1); 
                        firstTZOffset = wps.timezone_offset(1); 
                    end
                    
                    if size(wps, 1) > 2
                        wps.hidden(2:end-1)           = 1;
                        wps.hidden_lat(2:end-1)       = firstLat;
                        wps.hidden_lon(2:end-1)       = firstLon;
                        wps.hidden_ts(2:end-1)        = firstTS;
                        wps.hidden_speed(2:end-1)     = firstSpeed; 
                        wps.hidden_acc(2:end-1)       = firstAcc; 
                        wps.hidden_vacc(2:end-1)      = firstVAcc; 
                        wps.hidden_provider(2:end-1)  = firstProv; 
                        wps.hidden_tzoffset(2:end-1)  = firstTZOffset; 
                    end
                end
                
                obj = obj.updateWaypoints(wps);
                
            end
            
        end
        
        % Obfuscate temporal information
        function obj = obfuscateTemporal(obj) 
            
            % Precise times (can still be obfuscated by place/travel obf)
            if obj.obfuscate_temporal_granularity == 0
                return;
            end
            
            obj.tbl_routes      = obj.obfuscateStartEndTimestamp(obj.tbl_routes);
            obj.tbl_legs     = obj.obfuscateStartEndTimestamp(obj.tbl_legs);
            obj.tbl_dwells      = obj.obfuscateStartEndTimestamp(obj.tbl_dwells);
            obj.tbl_waypoints   = obj.obfuscateTimestamp(obj.tbl_waypoints);

        end
        
        % Push obfuscated data to output database
        function obj = pushObfuscatedData(obj)
            
            %
            % PLACES
            %
            output_places = obj.tbl_places;
            
            if output_places.hidden == 1
                output_places.lat = output_places.hidden_lat;
                output_places.lon = output_places.hidden_lon;
            end
                        
            % Remove fields which are not used for obfuscated output
            output_places.hidden                = [];
            output_places.hidden_lat            = [];
            output_places.hidden_lon            = [];
            output_places.hidden_first_dwellTS  = [];
            output_places.hidden_last_dwellTS   = [];
            output_places.hidden_timestamp      = [];
            output_places.first_dwell_starttime = [];
            output_places.last_dwell_endtime    = [];
            output_places.dwell_frequency       = [];
            output_places.dwell_regularity      = [];
            output_places.dwelltime_percentage  = [];
            output_places.dwelltime_sum         = [];
            output_places.dwelltime_rank        = [];
            output_places.placeloc_strength     = [];
            output_places.privacy_sensitivity   = [];      
            
            % Update fields
            output_places.uploadtime(:) = obj.datetime2epoch(datetime('now', 'TimeZone', 'Z'));

            % Push to output database
            obj.pushPlacesToDB(output_places);
            
            %
            % REVGEO
            %
            output_rgeo         = obj.tbl_revgeo;
            output_rgeo.hidden  = [];
            output_rgeo.privacy = [];
            output_rgeo.index   = [];
            
            % Update fields
            output_rgeo.uploadtime(:) = obj.datetime2epoch(datetime('now', 'TimeZone', 'Z'));
            
            obj.pushRGeoToDB(output_rgeo);
            
            
            %
            % DWELLS
            %
            output_dwells = obj.tbl_dwells;
            
            if output_dwells.hidden == 1
                output_dwells.start_ts  = output_dwells.hidden_start_ts;
                output_dwells.end_ts    = output_dwells.hidden_end_ts;
                output_dwells.duration  = output_dwells.hidden_duration;
            end
            
            if obj.obfuscate_temporal_granularity > 0
                output_dwells.start_ts  = output_dwells.hidden_start_ts;
                output_dwells.end_ts    = output_dwells.hidden_end_ts;
            end
            
            output_dwells.hidden                = [];
            output_dwells.hidden_start_ts       = [];
            output_dwells.hidden_end_ts         = [];
            output_dwells.hidden_duration       = [];
            output_dwells.dwell_loc_strength    = [];
            output_dwells.dwell_source          = [];
            output_dwells.location_accuracy     = [];
            output_dwells.lat                   = [];
            output_dwells.lon                   = [];
            output_dwells.duration              = [];
            output_dwells.overwrites            = [];
            output_dwells.overwritten_by        = [];
            output_dwells.index                 = [];
            output_dwells.obsolete              = [];
            output_dwells.privacy               = [];
            
            % Update fields
            output_dwells.uploadtime(:) = obj.datetime2epoch(datetime('now', 'TimeZone', 'Z'));

            % Push to output database
            obj.pushDwellsToDB(output_dwells);

            %
            % ROUTES
            %
            output_routes = obj.tbl_routes;
            
            % Substitute fields with hidden versions if hidden data
            if output_routes.hidden == 1
                output_routes.start_ts      = output_routes.hidden_start_ts;
                output_routes.end_ts        = output_routes.hidden_end_ts;
                output_routes.duration      = output_routes.hidden_duration;
                output_routes.distance      = output_routes.hidden_distance;
                output_routes.gis_distance  = output_routes.hidden_gis_distance;
            end
            
            if obj.obfuscate_temporal_granularity > 0
                output_routes.start_ts  = output_routes.hidden_start_ts;
                output_routes.end_ts    = output_routes.hidden_end_ts;
            end
            
            % Trim columns we don't need
            output_routes.hidden                = [];
            output_routes.hidden_start_ts       = [];
            output_routes.hidden_end_ts         = [];
            output_routes.hidden_duration       = [];
            output_routes.hidden_distance       = [];
            output_routes.hidden_gis_distance   = [];
            output_routes.privacy               = [];
            output_routes.obsolete              = [];
            output_routes.overwrites            = [];
            output_routes.overwritten_by        = [];
            output_routes.match_confidence      = [];
            output_routes.data_quality          = [];
            output_routes.index                 = [];
            
            % Update fields
            output_routes.uploadtime(:) = obj.datetime2epoch(datetime('now', 'TimeZone', 'Z'));
            
            % Push to output database
            obj.pushRoutesToDB(output_routes);
  
            %
            % LEGS
            %
            output_legs = obj.tbl_legs;
            
            % Substitute fields with hidden versions if hidden data
            if output_legs.hidden == 1
                output_legs.start_ts      = output_legs.hidden_start_ts;
                output_legs.end_ts        = output_legs.hidden_end_ts;
                output_legs.duration      = output_legs.hidden_duration;
                output_legs.distance      = output_legs.hidden_distance;
                output_legs.gis_distance  = output_legs.hidden_gis_distance;
                output_legs.firstloc_lat  = output_legs.hidden_firstloc_lat;
                output_legs.firstloc_lon  = output_legs.hidden_firstloc_lon;
                output_legs.lastloc_lat   = output_legs.hidden_lastloc_lat;
                output_legs.lastloc_lon   = output_legs.hidden_lastloc_lon;
            end
            
            if obj.obfuscate_temporal_granularity > 0
                output_legs.start_ts  = output_legs.hidden_start_ts;
                output_legs.end_ts    = output_legs.hidden_end_ts;
            end
            
            % Trim columns we don't need
            output_legs.hidden               = [];
            output_legs.hidden_firstloc_lat  = [];
            output_legs.hidden_firstloc_lon  = [];
            output_legs.hidden_lastloc_lat   = [];
            output_legs.hidden_lastloc_lon   = [];
            output_legs.hidden_start_ts      = [];
            output_legs.hidden_end_ts        = [];
            output_legs.hidden_duration      = [];
            output_legs.hidden_distance      = [];
            output_legs.privacy_sensitivity  = [];
            output_legs.obsolete             = [];
            output_legs.privacy              = [];
            output_legs.overwrites           = [];
            output_legs.overwritten_by       = [];
            output_legs.index                = [];
            
            % Update fields
            output_legs.uploadtime(:) = obj.datetime2epoch(datetime('now', 'TimeZone', 'Z'));
            
            % Push to output database
            obj.pushLegsToDB(output_legs);
  
            %
            % WAYPOINTS
            %
            output_waypoints = obj.tbl_waypoints;
            
            % Substitute fields with hidden versions if hidden data
            if output_waypoints.hidden == 1
                output_waypoints.timestamp       = output_waypoints.hidden_ts;
                output_waypoints.lat             = output_waypoints.hidden_lat;
                output_waypoints.lon             = output_waypoints.hidden_lon;
                output_waypoints.accuracy        = output_waypoints.hidden_acc;
                output_waypoints.vaccuracy       = output_waypoints.hidden_vacc;
                output_waypoints.speed           = output_waypoints.hidden_speed;
                output_waypoints.provider        = output_waypoints.hidden_provider;
                output_waypoints.timezone_offset = output_waypoints.hidden_tzoffset;
            end
            
            if obj.obfuscate_temporal_granularity > 0
                output_waypoints.timestamp       = output_waypoints.hidden_ts;
            end
            
            % Trim columns we don't need
            output_waypoints.privacy            = [];
            output_waypoints.hidden             = [];
            output_waypoints.hidden_acc         = [];
            output_waypoints.hidden_vacc        = [];
            output_waypoints.hidden_speed       = [];
            output_waypoints.hidden_provider    = [];
            output_waypoints.hidden_tzoffset    = [];
            output_waypoints.hidden_ts          = [];
            output_waypoints.hidden_lat         = [];
            output_waypoints.hidden_lon         = [];
            output_waypoints.index              = [];
            
            % Update fields
            output_waypoints.uploadtime(:) = obj.datetime2epoch(datetime('now', 'TimeZone', 'Z'));
            
            % Push to output database
            obj.pushWaypointsToDB(output_waypoints);
                       
        end
        
        % Clear data
        function obj = clear(obj)
            obj.tbl_dwells                  = [];
            obj.tbl_legs                    = [];
            obj.tbl_places                  = [];
            obj.tbl_routes                  = [];
            obj.tbl_waypoints               = [];
            obj.tbl_revgeo                  = [];
            obj.protectedAreas              = [];
        end
        
        % -----------------------------------------------------------------------
        
        
        % ------------- %
        % VISUALISATION %
        % ------------- %
        
        % Visualize protected areas
        function plotProtectedAreas(obj)
            
            pareas = obj.protectedAreas;
            obj.initFigure;
            hold on;
            
            for i = 1 : length(pareas)
                parea = pareas(i);
                place = obj.getPlaceByID(parea.place);
                
                if parea.privacy == 1
                    plot(parea.pgon, 'FaceColor','green','FaceAlpha',0.1);
                    plot(place.lon, place.lat, 'o', 'MarkerFaceColor','black', 'MarkerSize', 12);
                end
                if parea.privacy == 2
                    plot(parea.pgon, 'FaceColor','yellow','FaceAlpha',0.4);
                    plot(place.lon, place.lat, 'o', 'MarkerFaceColor','black', 'MarkerSize', 12);
                end
                if parea.privacy == 3
                    plot(parea.pgon, 'FaceColor','red','FaceAlpha',0.6);
                    plot(place.lon, place.lat, 'o', 'MarkerFaceColor','black', 'MarkerSize', 12);
                end
                
            end
            
        end
        
        % Plot protected area polygon
        function plotProtectedArea(obj, area)
            % Place.area
            if iscell(area)
                area = obj.getProtectedAreaForPlaceID(area{1}.place_id);
            end
            
            obj.initFigure;
            
            % ProtecterArea
            if ~isempty(area)
                if area.privacy == 1
                    plot(area.pgon, 'FaceColor','green','FaceAlpha',0.1);
                    % plot(area.place.lon, area.place.lat, 'o', 'MarkerFaceColor','black');
                end
                if area.privacy == 2
                    plot(area.pgon, 'FaceColor','yellow','FaceAlpha',0.4);
                    % plot(area.place.lon, area.place.lat, 'o', 'MarkerFaceColor','black');
                end
                if area.privacy == 3
                    plot(area.pgon, 'FaceColor','red','FaceAlpha',0.6);
                    % plot(area.place.lon, area.place.lat, 'o', 'MarkerFaceColor','black');
                end
                dx = 0.001;
                dy = 0.001;
                text(area.geo(1), area.geo(2), area.name);
            end
            
        end
        
        % Visualize hidden waypoints
        function plotHiddenWaypoints(obj)
            wps = obj.tbl_waypoints;
            wps_hidden = wps(wps.hidden == 1,:);
            obj.plotWaypoints(wps_hidden);
        end
        
        % Plot input waypoints
        function plotWaypoints(obj, waypoints)
            
            obj.initFigure();
            
            geo = [waypoints.lon, waypoints.lat];
            if ~isempty(geo)
                plot(geo(:,1), geo(:,2),                  ...
                    'LineStyle', 'none',                  ...
                    'Marker', '.',                        ...
                    'MarkerEdgeColor', 'black',           ...
                    'MarkerFaceColor', 'black',           ...
                    'MarkerSize', 5);
            end
            
            
        end
        
        % Visualise Places, th_dwellTime defines minimum dwellTime to display a Place
        function plotPlaces(obj)
           
            places  = obj.tbl_places;
            dwells  = obj.tbl_dwells;
            nDwells = size(dwells, 1);
            nPlaces = size(places, 1);
            
            % Calculate dwellTime per Places
            placeDwellTime = zeros(max(places.id), 1);
            for i = 1:nDwells
                dwellPlace = dwells.place_id(i);
                if (dwellPlace < 0) % Unknown DwellPlace
                    continue;
                end
                placeDwellTime(dwellPlace) = placeDwellTime(dwellPlace) + dwells.duration(i);
            end
            totalDwellTime = sum(placeDwellTime);
            
            % Initialize figure if needed + set googlemap if not already
            obj.initFigure();
            displayedPlaces = [];
            % Plot Places
            markerColor  = jet(50);
            for i = 1:nPlaces
                place = places(i,:);
                geoCoords = [place.lon, place.lat];
                dwellTime = placeDwellTime(place.id);
                dwellWgt  = (dwellTime / totalDwellTime) * 100;
                
                if dwellTime >= th_dwellTime
                    colorIdx = min([50, max([1, round(dwellWgt)])]);
                    plot(geoCoords(1), geoCoords(2), 'color', 'black',  ...
                        'marker', 'o', 'markerSize', 10,                ...
                        'MarkerFaceColor', markerColor(colorIdx,:));
                    
                    dx = 0.00012;
                    dy = 0.00012;
                    text(geoCoords(1) + dx, geoCoords(2) + dy, num2str(place.id));
                    displayedPlaces(end+1) = place.id;
                end
            end
        end
        
        % Plot leg
        function plotLeg(obj, leg, obfuscate)
            
            if nargin < 3
                obfuscate = 1;
            end
            
            % Geo waypoints + hide waypoints in protected areas
            legWPs = obj.getWaypointsForLeg(leg.id);
            
            legGeo = [];
            if ~isempty(legWPs)
                if obfuscate == 0
                    legGeo = [legWPs.lon, legWPs.lat];
                    legGeoHidden = [];
                else
                    isHidden = logical(legWPs.hidden);
                    legGeo = [legWPs.lon, legWPs.lat];
                    legGeo(isHidden, 1) = legWPs.hidden_lon(isHidden);
                    legGeo(isHidden, 2) = legWPs.hidden_lat(isHidden);
                    legGeoHidden = [legWPs.lon(isHidden), legWPs.lat(isHidden)];
                end
            end
            
            % Get transport mode and it's color code
            modeID    = leg.transport_mode;
            modeColor = obj.getModeColor(modeID);
            
            % Plot leg geo
            if ~isempty(legGeo)
                plot(legGeo(:,1), legGeo(:,2),                  ...
                    'LineStyle', '-.',                          ...
                    'Color', modeColor,                         ...
                    'Marker', 'o',                              ...
                    'MarkerEdgeColor', modeColor,               ...
                    'MarkerFaceColor', modeColor,               ...
                    'MarkerSize', 5);
            end
            if ~isempty(legGeoHidden)
                plot(legGeoHidden(:,1), legGeoHidden(:,2),      ...
                    'LineStyle', 'none',                        ...
                    'Color', modeColor,                         ...
                    'Marker', 'x',                              ...
                    'MarkerEdgeColor', modeColor,               ...
                    'MarkerFaceColor', modeColor,               ...
                    'MarkerSize', 5);
            end
        end
        
        % Inspect Route; second parameter controls plotting raw(0), obfuscated(1) or both(2) results
        function plotRoute(obj, routeID, obfuscate)
            
            if nargin < 3
                obfuscate = 1;
            end
            
            % Show both obfuscated and plain versions
            if obfuscate == 2
                obj.plotRoute(routeID, 0);
                obj.plotRoute(routeID, 1);
                return;
            end
            
            route = obj.getRouteByID(routeID);
            
            if isempty(route)
                disp(strcat('could not find route with id: ', num2str(routeID)));
                return;
            end
            
            routeStartPlace = obj.getPlaceByID(route.start_place);
            routeEndPlace = obj.getPlaceByID(route.end_place);
            
            obj.initFigure(1);
            hold on;
            
            % RouteStartPlace
            route_protectedAreas = [];
            if obfuscate && ~isempty(routeStartPlace) && routeStartPlace.privacy_sensitivity > 1
                route_protectedAreas = obj.getProtectedAreaForPlaceID(routeStartPlace.id);
                obj.plotProtectedArea(route_protectedAreas(1));
            else
                if isempty(routeStartPlace)
                    routeStartGeo = [-1, -1];
                else
                    routeStartGeo = [routeStartPlace.lon, routeStartPlace.lat];
                end
                
                % Plot route start
                if routeStartGeo(1) ~= -1
                    plot(routeStartGeo(1), routeStartGeo(2),            ...
                        'Marker', 's',                                  ...
                        'MarkerEdgeColor', 'green',                     ...
                        'MarkerFaceColor', 'green',                     ...
                        'MarkerSize', 12);
                end
            end
            
            % RouteEndPlace
            if obfuscate && ~isempty(routeEndPlace) && routeEndPlace.privacy_sensitivity > 1
                if isempty(route_protectedAreas)
                    route_protectedAreas = obj.getProtectedAreaForPlaceID(routeEndPlace.id);
                else
                    route_protectedAreas(end + 1) = obj.getProtectedAreaForPlaceID(routeEndPlace.id);
                end
                obj.plotProtectedArea(route_protectedAreas(end));
            else
                
                routeEndPlace = obj.getPlaceByID(route.end_place);
                if isempty(routeEndPlace)
                    routeEndGeo = [-1, -1];
                else
                    routeEndGeo = [routeEndPlace.lon, routeEndPlace.lat];
                end
                
                % Plot route end place
                if routeEndGeo(1) ~= -1
                    plot(routeEndGeo(1), routeEndGeo(2),            ...
                        'Marker', 's',                              ...
                        'MarkerEdgeColor', 'red',                   ...
                        'MarkerFaceColor', 'red',                   ...
                        'MarkerSize', 12)
                end
            end
            
            modes = [];
            legs  = obj.getLegsByRouteID(route.id);
            for i = 1 : size(legs, 1)
                leg = legs(i,:);
                % Skip nonresolved legs
                if isempty(leg)
                    continue;
                end
                if isempty(modes)
                    modes = strcat(obj.getModeName(leg.transport_mode), "(", num2str(leg.privacy_sensitivity), ")");
                else
                    modes = strcat(modes, ", ", obj.getModeName(leg.transport_mode), "(", num2str(leg.privacy_sensitivity), ")");
                end
                
                obj.plotLeg(leg, obfuscate);
            end
            
            if obj.obfuscate_temporal_granularity > 0 || route.hidden
                startDate = datestr(obj.epoch2datetime(route.hidden_start_ts));
            else
                startDate = datestr(obj.epoch2datetime(route.start_ts));
            end
            
            fprintf('[Date: ');
            fprintf(startDate);
            fprintf(' ');
            fprintf('Route modes: ');
            if isempty(modes)
                modes = 'empty modes list';
            end
            fprintf(modes);
            fprintf(']');
            fprintf('\n');
            
            [maxLon, maxLat, minLon, minLat] = obj.getBoundsForRoute(routeID);
            obj.setFigureLims(minLat, maxLat, minLon, maxLon);
            
        end

        % Plot routes based on leg privacy category
        function plotRoutesWithPrivacyCategory(obj, privacyCat, routeIDs) 
           
            routes = obj.tbl_routes;
            nRoutes = size(routes, 1);
            
            if nargin < 3
                routeIDs = routes.id;
            end
            
            obj.initFigure(1);
            hold on;
            
            aggrLocs = [];
            for i = 1:nRoutes
                
                thisRoute = routes(i, :);
                
                % Skip unrequested Routes
                if ~ismember(thisRoute.id, routeIDs)
                    continue;
                end
                
                routeLegs = obj.getLegsByRouteID(thisRoute.id);
                
                if isempty(routeLegs)
                    continue;
                end
                
                if isnan(routeLegs.privacy_sensitivity(1)) 
                    continue;
                end
                
                % Plot Route
                nLegs = size(routeLegs, 1);
                for j = 1:nLegs
                    
                    thisLeg = routeLegs(j,:);
                    modeID  = thisLeg.transport_mode;
                    
                    % Skip nonresolved legs
                    if isempty(thisLeg) || thisLeg.firstloc_lat == -1
                        continue;
                    end

                    legWPs   = obj.getWaypointsForLeg(thisLeg.id);
                    
                    modeColor = obj.getModeColor(modeID);
                    if isempty(legWPs)
                        legGeo = [];
                    else
                        legGeo = [legWPs.lon, legWPs.lat];
                    end
                    
                    if thisLeg.privacy_sensitivity ~= privacyCat
                        continue;
                    end
                                       
                    % Plot leg locations
                    if ~isempty(legGeo)
                        plot(legGeo(:,1), legGeo(:,2),                  ...
                            'LineStyle', ':',                           ...
                            'Color', modeColor,                         ...
                            'Marker', '.',                              ...
                            'MarkerEdgeColor', modeColor,               ...
                            'MarkerFaceColor', modeColor,               ...
                            'MarkerSize', 12);
                    end
                    
                    aggrLocs = [aggrLocs; legGeo];
                end
                
            end
            
            if ~isempty(aggrLocs)
                x_maxlat = max(aggrLocs(:,1)) + 0.01;
                x_minlat = min(aggrLocs(:,1)) - 0.01;
                y_maxlon = max(aggrLocs(:,2)) + 0.01;
                y_minlon = min(aggrLocs(:,2)) - 0.01;
                xlim([x_minlat, x_maxlat]);
                ylim([y_minlon, y_maxlon]);
            end

        end

        % ----------------------------------------------------------------------- %
        
        
        % --------------------- %
        % TRAVEL OBJECT GETTERS %
        % --------------------- %
        
        % Find protected area matching input placeID
        function pa = getProtectedAreaForPlaceID(obj, placeID)
            pa = [];
            for i = 1 : length(obj.protectedAreas)
                if obj.protectedAreas(i).place == placeID
                    pa = obj.protectedAreas(i);
                end
            end
        end
        
        % Return Place matching input placeID; empty if no matches found
        function p = getPlaceByID(obj, placeID)
            places = obj.tbl_places;
            p = [];
            for i = 1:size(places, 1)
                if places.id(i) == placeID
                    p = places(i, :);
                    break;
                end
            end
        end
        
        % Return dwell matching input dwellID; empty if no matches found
        function d = getDwellByID(obj, dwellID)
            dwells = obj.tbl_dwells;
            d = [];
            for i = 1:size(dwells, 1)
                if dwells.id(i) == dwellID
                    d = dwells(i, :);
                    break;
                end
            end
        end
        
        % Return Route matching input routeID; empty if no matches found
        function r = getRouteByID(obj, routeID)
            routes = obj.tbl_routes;
            r = [];
            for i = 1:size(routes, 1)
                if routes.id(i) == routeID
                    r = routes(i, :);
                    break;
                end
            end
        end
        
        % Return Waypoints for input leg ID
        function resWPs = getWaypointsForLeg(obj, legId)
            waypoints = obj.tbl_waypoints;
            i_wps = waypoints.leg_id == legId;
            resWPs = waypoints(i_wps,:);
            if size(resWPs,1) == 0
                resWPs = [];
            end
        end
        
        % Return Waypoints for input Route ID
        function resWPs = getWaypointsForRoute(obj, routeId)
            waypoints = obj.tbl_waypoints;
            i_wps = waypoints.route_id == routeId;
            resWPs = waypoints(i_wps,:);
            if size(resWPs,1) == 0
                resWPs = [];
            end
        end
        
        % Return Dwells matching input placeID, empty if none found
        function placeDwells = getDwellsForPlace(obj, placeID)
            dwells  = obj.tbl_dwells;
            nDwells = size(dwells, 1);
            placeDwells = [];
            for i = 1:nDwells
                d = dwells(i, :);
                if d.place_id == placeID
                    if isempty(placeDwells)
                        placeDwells = d;
                    else
                        placeDwells(end+1, :) = d;
                    end
                end
            end
        end
        
        % Return Reverse Geocode matching input placeId
        function rgeo = getReverseGeocodeForPlace(obj, placeID)
            
            rgeos = obj.tbl_revgeo;
            rgeo  = [];
            
            for i = 1 : size(rgeos,1)                
                if rgeos.parent_place(i) == placeID
                    rgeo = rgeos(i,:);
                    return;
                end
            end
            
        end
        
        % Return leg given Id
        function leg = getLegByID(obj, legID)
            leg = [];
            for i=1:size(obj.tbl_legs,1)
                leg = obj.tbl_legs(i,:);
                if leg.id == legID
                    break;
                end
            end
        end
        
        % Return route legs matching input routeID; empty if no matches found
        function legs_selected = getLegsByRouteID(obj, routeId)
            
            legs_selected = [];
            legs_all = obj.tbl_legs;
            
            for i = 1:size(legs_all, 1)
                leg = legs_all(i,:);
                if leg.route_id == routeId
                    if isempty(legs_selected)
                        legs_selected = leg;
                    else
                        legs_selected(end + 1, :) = leg;
                    end
                end
            end
        end
        
    end
    
    % PRIVATE METHODS
    methods (Access = protected)
        
        % Hide sensitive waypoints by moving them to centroid of theprotectedArea
        function waypoints = hideSensitiveWaypointsInPAs(obj, waypoints, protectedAreas, replaceWithCentroid)
            
            if isempty(protectedAreas) || isempty(waypoints)
                return;
            end
            
            % Should function replace hidden waypoint geos with protected area centroid
            if nargin < 4
                replaceWithCentroid = 0;
            end
   
            waypoints.isPublictTransit = ismember(waypoints.transport_mode, obj.MODES_PUBLICTRANSIT);
            
            for i = 1 : length(protectedAreas)
                
                if iscell(protectedAreas(i))
                    protectedArea = protectedAreas{i};
                else
                    protectedArea = protectedAreas(i);
                end
                
                if isempty(protectedArea)
                    continue;
                end
                
                inProtectedArea = isinterior(protectedArea.pgon, waypoints.lon, waypoints.lat);
                l_hide = (inProtectedArea & waypoints.isPublictTransit == 0);
                
                if sum(l_hide) == 0
                    continue;
                end
                waypoints.hidden(l_hide)        = 1;
                waypoints.privacy(l_hide)       = protectedArea.privacy;     
                
                if replaceWithCentroid
                    waypoints.hidden_lon(l_hide) = protectedArea.geo(1);
                    waypoints.hidden_lat(l_hide) = protectedArea.geo(2);
                end
            end
        end
        
        % Check if input geo is inside any of the input polygons
        function isInside = isInsideArea(obj, geo, polys)
            
            isInside = 0;
            
            for i = 1 : length(polys)
                isInside = isinterior(polys(i).pgon, geo(1), geo(2));
                if isInside == 1
                    return;
                end
            end
            
        end
        
        % Map transport mode cell strings to integer ids
        function obj = tmodes2integers(obj)
            % TransportMode string -> id
            tmode_str_cell = obj.tbl_waypoints.transport_mode;
            tmode = zeros(length(tmode_str_cell), 1);
            for i = 1 : length(tmode_str_cell)
                tmode_str = tmode_str_cell{i};
                tmode(i) = str2num(tmode_str);
            end
            
            obj.tbl_waypoints.transport_mode = tmode;
        end
        
        % Map provider strings to provider ID
        function obj = providers2integers(obj)
            % Provider string -> id
            provider_str_cell = obj.tbl_waypoints.provider;
            provider = zeros(length(provider_str_cell), 1);
            for i = 1 : length(provider_str_cell)
                provider_str = provider_str_cell{i};
                provider(i) = str2num(provider_str);
            end
            
            obj.tbl_waypoints.provider = provider;
        end
        
        % Query Output area for input LAT, LON
        function parsed_response = queryOutputArea(obj, lat, lon)
            
            baseUrl = strcat("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/", ...
                "Lower_Layer_Super_Output_Areas_December_2011_Boundaries_EW_BFE_V2/FeatureServer/0/query?");
            
            parameters = strcat("where=1%3D1&outFields=OBJECTID,LONG_,LAT,LSOA11NM&", ...
                "geometryType=esriGeometryPoint&", ...
                "inSR=4326&", ...
                "spatialRel=esriSpatialRelWithin&outSR=4326&", ...
                "f=json&", ...
                "geometry=");
            
            latlon = strcat(num2str(lon), "%2C", num2str(lat));
            query  = strcat(baseUrl, parameters, latlon);
            
            if obj.use_caching_for_OAQueries
                currDir = pwd;
                cd(obj.OAQuery_cacheDir);
            end
            
            raw_response = [];
            try
                % Check cache
                if obj.use_caching_for_OAQueries
                    fname = strcat(num2str(lat),"_",num2str(lon),".mat");
                    if isfile(fname)
                        load(fname, 'raw_response');
                    else
                        raw_response = urlread(query);
                        save(fname,'raw_response');
                    end
                else
                    raw_response = urlread(query);
                end
            catch ME
                disp("Error retrieving response from https://services1.arcgis.com");
            end
            
            parsed_response = [];
            if ~isempty(raw_response)
                disp(strcat('parsing reply: ', raw_response));
                parsed_response = obj.parseArcgisReply(raw_response);
            end
            
            if isempty(parsed_response.geom)
                % disp(strcat('could not parse for location: ', num2str(lat), ',', num2str(lon)));
            end
            
            % Swap back to currDir
            if obj.use_caching_for_OAQueries
                cd(currDir);
            end
            
        end
        
        % Parse ARCGIS reply about Output Areas
        function output = parseArcgisReply(obj, raw)
            
            output.name = "";
            output.geom = [];
            
            try
                json = jsondecode(raw);
                output.name = json.features.attributes.LSOA11NM;
                output.geom = squeeze(json.features.geometry.rings);
            catch ME
                % disp(strcat("Unable to parse ArcgisReply: ", raw));
            end
        end
        
        % Execute SQL
        function result = executeSQL(obj, sql)
            if isempty(obj.db_conn)
                disp("Connection to database not established; run connectToInputDB first");
                result = [];
            else
                disp(["Running query: ", sql]);
                result = obj.db_conn.fetch(sql);
            end
        end
        
        % Get night-time hours between start and end dates
        function night_hours = getNightHours(obj, startDate, endDate)
            
            NIGHT_HOURS = [0,6];
            
            [start_hh, start_mm, start_ss] = obj.getTimeFromDate(startDate);
            [end_hh, end_mm, end_ss]       = obj.getTimeFromDate(endDate);
            
            % Use recursion in case of day changes
            nightTimeSeconds = 0;
            if weekday(startDate) ~= weekday(endDate)
                nextMidnight = obj.getNextMidnight(startDate);
                nightTimeSeconds = nightTimeSeconds + ...
                    obj.getNightHours(nextMidnight, endDate) * 3600;
                end_hh = 23;
                end_mm = 59;
                end_ss = 59;
            end
            
            
            % Calculate dwell time between 0 - 6
            if start_hh < 6 && end_hh >= 0
                hours_ = min(6, end_hh) - max(0, start_hh);
                
                reduce_seconds = 0;
                if start_hh >= 0 && start_hh < 6
                    reduce_seconds = start_mm * 60 + start_ss;
                end
                
                add_seconds = 0;
                if end_hh >= 0 && end_hh < 6
                    add_seconds = end_mm * 60 + end_ss;
                end
                
                nightTimeSeconds = nightTimeSeconds + hours_ * 3600 ...
                    - reduce_seconds + add_seconds;
            end
            
            night_hours = nightTimeSeconds / 3600;
        end
        
        % Get business-time hours between start and end dates
        function business_hours = getBusinessHours(obj, startDate, endDate)
            
            BUSINESS_HOURS = [9,17];
            
            [start_hh, start_mm, start_ss] = obj.getTimeFromDate(startDate);
            [end_hh, end_mm, end_ss]       = obj.getTimeFromDate(endDate);
            
            % Use recursion in case of day changes
            businessTimeSeconds = 0;
            if weekday(startDate) ~= weekday(endDate)
                nextMidnight = obj.getNextMidnight(startDate);
                businessTimeSeconds = businessTimeSeconds + ...
                    obj.getBusinessHours(nextMidnight, endDate) * 3600;
                end_hh = 23;
                end_mm = 59;
                end_ss = 59;
            end
            
            
            % Calculate dwell time between 9 - 17
            if start_hh < 17 && end_hh >= 9
                hours_ = min(17, end_hh) - max(9, start_hh);
                
                reduce_seconds = 0;
                if start_hh >= 9 && start_hh < 17
                    reduce_seconds = start_mm * 60 + start_ss;
                end
                
                add_seconds = 0;
                if end_hh >= 9 && end_hh < 17
                    add_seconds = end_mm * 60 + end_ss;
                end
                
                businessTimeSeconds = businessTimeSeconds + hours_ * 3600 ...
                    - reduce_seconds + add_seconds;
            end
            
            business_hours = businessTimeSeconds / 3600;
            
        end
        
        % Get time in hours, minutes, seconds from a date string
        function [hh,mm,ss] = getTimeFromDate(obj, dateStr)
            
            hh = -1;
            mm = -1;
            ss = -1;
            
            if isempty(dateStr)
                disp('Empty dateStr');
                return;
            end
            
            splits = strsplit(dateStr);
            
            if length(splits) ~= 2
                disp('Wrong dateStr format');
                disp(dateStr);
                return;
            end
            
            timestr    = splits{2};
            timesplits = strsplit(timestr,':');
            
            if length(timesplits) ~= 3
                disp('Wrong dateStr format');
                disp(dateStr);
                return;
            end
            
            hh = str2num(timesplits{1});
            mm = str2num(timesplits{2});
            ss = str2num(timesplits{3});
        end
        
        % Return next midnight at 00:00
        function nextMidnight = getNextMidnight(obj, dateStr)
            
            [hh, mm, ss] = obj.getTimeFromDate(dateStr);
            
            nextMidnight = datestr(datetime(dateStr) + hours(23 - hh) + ...
                minutes(59 - mm) + seconds(60 - ss), "dd-mmm-yyyy HH:MM:SS");
            
        end
        
        % Get geo bounds for input route
        function [maxLon, maxLat, minLon, minLat] = getBoundsForRoute(obj, routeID)
            
            route = obj.getRouteByID(routeID);
            wps = obj.getWaypointsForRoute(routeID);
            
            startPlacePA = obj.getProtectedAreaForPlaceID(route.start_place);
            endPlacePA = obj.getProtectedAreaForPlaceID(route.end_place);
            
            if isempty(wps)
                maxWPLat = 90;
                minWPLat = -90;
                maxWPLon = 180;
                minWPLon = -180;
            else
                maxWPLat = max(wps.lat);
                minWPLat = min(wps.lat);
                maxWPLon = max(wps.lon);
                minWPLon = min(wps.lon);
            end
            
            startPlaceMaxLon  = 180;
            endPlaceMaxLon    = 180;
            startPlaceMaxLat  = 90;
            endPlaceMaxLat    = 90;
            
            startPlaceMinLon  = -180;
            endPlaceMinLon    = -180;
            startPlaceMinLat  = -90;
            endPlaceMinLat    = -90;
            
            if ~isempty(startPlacePA)
                startPlaceMaxLon = startPlacePA.maxLon;
                startPlaceMinLon = startPlacePA.minLon;
                startPlaceMaxLat = startPlacePA.maxLat;
                startPlaceMinLat = startPlacePA.minLat;
            end
            
            if ~isempty(endPlacePA)
                endPlaceMaxLon = endPlacePA.maxLon;
                endPlaceMinLon = endPlacePA.minLon;
                endPlaceMaxLat = endPlacePA.maxLat;
                endPlaceMinLat = endPlacePA.minLat;
            end
            
            maxLon = max([maxWPLon, startPlaceMaxLon, endPlaceMaxLon]);
            maxLat = max([maxWPLat, startPlaceMaxLat, endPlaceMaxLat]);
            minLon = min([minWPLon, startPlaceMinLon, endPlaceMinLon]);
            minLat = min([minWPLat, startPlaceMinLat, endPlaceMinLat]);
            
        end
        
        % Get mode color corresponding to mode ID
        function color = getModeColor(obj, modeID)
            
            switch(modeID)
                case obj.MODEID_UNKNOWN
                    color = hex2rgb(obj.COLOUR_DEFAULT);
                case obj.MODEID_STATIONARY
                    color = hex2rgb(obj.COLOUR_STATIONARY);
                case obj.MODEID_WALK
                    color = hex2rgb(obj.COLOUR_WALK);
                case obj.MODEID_RUN
                    color = hex2rgb(obj.COLOUR_RUN);
                case obj.MODEID_BIKE
                    color = hex2rgb(obj.COLOUR_BICYCLE);
                case obj.MODEID_AUTOMOTIVE
                    color = hex2rgb(obj.COLOUR_AUTOMOTIVE);
                case obj.MODEID_BUS
                    color = hex2rgb(obj.COLOUR_BUS);
                case obj.MODEID_TRAIN
                    color = hex2rgb(obj.COLOUR_TRAIN);
                case obj.MODEID_TRAM
                    color = hex2rgb(obj.COLOUR_TRAM);
                case obj.MODEID_METRO
                    color = hex2rgb(obj.COLOUR_METRO);
                case obj.MODEID_CAR
                    color = hex2rgb(obj.COLOUR_CAR);
                case obj.MODEID_BOAT
                    color = hex2rgb(obj.COLOUR_BOAT);
                case obj.MODEID_AERIAL
                    color = hex2rgb(obj.COLOUR_AERIAL);
                case obj.MODEID_PUBLICTRANS
                    color = hex2rgb(obj.COLOUR_BUS);
                otherwise
                    disp('Error [getModeColor]: Unknown modeID');
                    color = hex2rgb(obj.COLOUR_DEFAULT);
            end
            
        end
        
        % Get mode name
        function name = getModeName(obj, modeID)
            switch(modeID)
                case obj.MODEID_UNKNOWN
                    name = "unknown";
                case obj.MODEID_STATIONARY
                    name = "stationary";
                case obj.MODEID_WALK
                    name = "walk";
                case obj.MODEID_RUN
                    name = "run";
                case obj.MODEID_BIKE
                    name = "bicycle";
                case obj.MODEID_AUTOMOTIVE
                    name = "automotive";
                case obj.MODEID_BUS
                    name = "bus";
                case obj.MODEID_TRAIN
                    name = "train";
                case obj.MODEID_TRAM
                    name = "tram";
                case obj.MODEID_METRO
                    name = "metro";
                case obj.MODEID_CAR
                    name = "car";
                case obj.MODEID_BOAT
                    name = "boat";
                case obj.MODEID_AERIAL
                    name = "aerial";
                case obj.MODEID_PUBLICTRANS
                    name = "publicTransit";
                otherwise
                    disp('Error [getModeName]: Unknown modeID');
                    name = "unknown";
            end
        end
        
        % Set Figure axes limits
        function obj = setFigureLims(obj, x_minlat, x_maxlat, y_minlon, y_maxlon)
            ylim([x_minlat, x_maxlat]);
            xlim([y_minlon, y_maxlon]);
        end
        
        % Initialize figure, second parameters controls wether to open new
        % figure window; [0 = same figure, 1 = new figure]
        function obj = initFigure(obj, newFigure)
            
            if nargin < 2
                newFigure = 0;
            end
            
            h = [];
            if ~newFigure
                h = findobj('type','figure','name', obj.figureName_gmap);
            end
            
            if isempty(h)
                % Add googlemap & update figureName
                h = figure;
                h.Position = obj.figure_pos_size;
                plot_google_map(h); % External class, see http://www.mathworks.com/matlabcentral/fileexchange/24113
                hold on;
                set(h,'name',obj.figureName_gmap);
            end
            
        end
        
        % Convert timestamp to datetime obj
        function DT = epoch2datetime(obj, ts)
            DT = datetime(ts/1000.0, 'convertFrom', 'posixtime');
        end
        
        % Convert datetime object to epoch timestamp in milliseconds
        function epoch = datetime2epoch(obj, dt)
            warning('off', obj.warning_structOnObject);
            dtStruct = struct(dt);
            epoch = dtStruct.data;
            warning('on', obj.warning_structOnObject);
        end
        
        % Update waypoints
        function obj = updateWaypoints(obj, wps)
            
            for i = 1 : size(wps,1)
                i_wp = find(obj.tbl_waypoints.index == wps.index(i), 1, 'first');
                obj.tbl_waypoints(i_wp,:) = wps(i, 1:size(obj.tbl_waypoints,2)); % omit any extra cols
            end
            
        end
        
        % Update routes
        function obj = updateRoutes(obj, routes)            
            for i = 1 : size(routes,1)
                i_route                     = find(obj.tbl_routes.index == routes.index(i), 1, 'first');
                obj.tbl_routes(i_route,:)   = routes(i, 1:size(obj.tbl_routes,2)); % omit any extra cols
            end
        end
        
        % Updates Legs
        function obj = updateLegs(obj, legs)
            for i = 1 : size(legs,1)
                i_leg                  = find(obj.tbl_legs.index == legs.index(i), 1, 'first');
                obj.tbl_legs(i_leg,:)  = legs(i, 1:size(obj.tbl_legs,2)); % omit any extra cols
            end
        end
        
        % Update Places
        function obj = updatePlace(obj, places)
            for i = 1 : size(places,1)
                i_place                     = find(obj.tbl_places.id == places.id(i), 1, 'first');
                obj.tbl_places(i_place,:)   = places(i, 1:size(obj.tbl_places,2)); % omit any extra cols
            end
        end
        
        % Update dwells
        function obj = updateDwells(obj, dwells)
            for i = 1 : size(dwells,1)
                i_dwell                     = find(obj.tbl_dwells.index == dwells.index(i), 1, 'first');
                obj.tbl_dwells(i_dwell,:)   = dwells(i, 1:size(obj.tbl_dwells,2)); % omit any extra cols
            end
        end
        
        % Update Reverse Geocodes
        function obj = updateRGeos(obj, rgeos)
            for i = 1 : size(rgeos,1)
                i_rgeo                     = find(obj.tbl_revgeo.index == rgeos.index(i), 1, 'first');
                obj.tbl_revgeo(i_rgeo,:)   = rgeos(i, 1:size(obj.tbl_revgeo,2)); % omit any extra cols
            end
        end
        
        % Get distance of trajectory formed by input waypoints.
        % Parameter hidden allows calculating non-hidden trajectory length
        function d = getWaypointsDistance(obj, wps, hidden)
            geo = zeros(size(wps,1), 2);
            j = 1;
            for i = 1 : size(wps,1)
                if hidden && wps.hidden(i)
                    continue;
                end
                geo(j,:) = [wps.lat(i), wps.lon(i)];
                j = j + 1;
            end
            
            geo(j:end,:) = [];
            
            d = obj.getTrajectoryDistance(geo);
        end
        
        % Calculate trajectory distance (in meters) given matrix of geo: [n x (lat,lon)]
        function distSum = getTrajectoryDistance(obj, geo)
            distSum = 0;
            nGeo    = size(geo, 1);
            if nGeo < 2
                % disp('getTrajectoryDistance: trajectory should have more than 1 data point!');
                distSum = 0;
                return;
            end
            for i = 2:nGeo
                prevGeo = [geo(i-1, 1), geo(i-1, 2)];
                thisGeo = [geo(i, 1), geo(i, 2)];
                stepD   = deg2km(distance('gc', prevGeo(1), prevGeo(2), thisGeo(1), thisGeo(2))) * 1000;
                distSum = distSum + stepD;
            end
        end
        
        % Get distance (in meters) between two geo locations in [lat, lon]
        function d = getDistanceBetween(obj, geo1, geo2)
            
            % Handle Waypoint input
            if istable(geo1)
                lat = geo1.lat;
                lon = geo1.lon;
                geo1 = [lat, lon];
                
                lat = geo2.lat;
                lon = geo2.lon;
                geo2 = [lat, lon];
            end
            
            
            d = deg2km(distance('gc', geo1(1), geo1(2), geo2(1), geo2(2), ...
                'deg')) * 1000;
        end
        
        % Get dwell duration type
        function durationType = getDwellDurationType(obj, dwell)
            
            t_mins = dwell.duration / (1000.0 * 60);
            
            if t_mins < 30
                durationType = 1;
                return;
            end
            
            if t_mins < 120
                durationType = 2;
                return;
            end
            
            start_dt   = obj.epoch2datetime(dwell.start_ts);
            end_dt     = obj.epoch2datetime(dwell.end_ts);
            nighthours = obj.getNightHours(datestr(start_dt), datestr(end_dt));
            
            if nighthours > 0 && t_mins > 240
                durationType = 4;
                return;
            end
            
            durationType = 3;
        end
        
        % Round tbl.start_ts and tbl.end_ts to level set in class variable
        function tbl = obfuscateStartEndTimestamp(obj, tbl)
            
            level = obj.obfuscate_temporal_granularity;
            
            % HOUR
            if level == obj.OBF_HOUR   
                start_dt            = obj.epoch2datetime(tbl.start_ts);
                end_dt              = obj.epoch2datetime(tbl.end_ts);     
                tbl.hidden_start_ts = obj.datetime2epoch(dateshift(start_dt, 'start', 'hour'));
                tbl.hidden_end_ts   = obj.datetime2epoch(dateshift(end_dt, 'start', 'hour'));
            end
            
            % DATE
            if level == obj.OBF_DATE
                start_dt            = obj.epoch2datetime(tbl.start_ts);
                end_dt              = obj.epoch2datetime(tbl.end_ts);
                tbl.hidden_start_ts = obj.datetime2epoch(dateshift(start_dt, 'start', 'day'));
                tbl.hidden_end_ts   = obj.datetime2epoch(dateshift(end_dt, 'start', 'day'));            
            end
            
            % AM/PM
            if level == obj.OBF_AMPM
                start_dt        = obj.epoch2datetime(tbl.start_ts);
                end_dt          = obj.epoch2datetime(tbl.end_ts);
                start_dt_i_pm   = start_dt.Hour >= 12;
                start_dt_i_am   = start_dt.Hour < 12;
                end_dt_i_pm     = end_dt.Hour >= 12;
                end_dt_i_am     = end_dt.Hour < 12;
                
                tbl.hidden_start_ts(start_dt_i_am) = obj.datetime2epoch(dateshift(start_dt(start_dt_i_am), 'start', 'day'));
                tbl.hidden_start_ts(start_dt_i_pm) = obj.datetime2epoch(dateshift(start_dt(start_dt_i_pm), 'start', 'day') + hours(12));  
                tbl.hidden_end_ts(end_dt_i_am)     = obj.datetime2epoch(dateshift(end_dt(end_dt_i_am), 'start', 'day'));
                tbl.hidden_end_ts(end_dt_i_pm)     = obj.datetime2epoch(dateshift(end_dt(end_dt_i_pm), 'start', 'day') + hours(12));                     
            end
            
        end
        
        % Round tbl.timestamp s to level set in class variable
        function tbl = obfuscateTimestamp(obj, tbl)
            
            level = obj.obfuscate_temporal_granularity;
            
            % HOUR
            if level == obj.OBF_HOUR   
                ts_dt         = obj.epoch2datetime(tbl.timestamp);    
                tbl.hidden_ts = obj.datetime2epoch(dateshift(ts_dt, 'start', 'hour'));
            end
            
            % DATE
            if level == obj.OBF_DATE
                ts_dt         = obj.epoch2datetime(tbl.timestamp);
                tbl.hidden_ts = obj.datetime2epoch(dateshift(ts_dt, 'start', 'day'));
            end
            
            % AM/PM
            if level == obj.OBF_AMPM
                ts_dt = obj.epoch2datetime(tbl.timestamp);
                
                i_pm = ts_dt.Hour >= 12;
                i_am = ts_dt.Hour < 12;
                
                tbl.hidden_ts(i_am) = obj.datetime2epoch(dateshift(ts_dt(i_am), 'start', 'day'));
                tbl.hidden_ts(i_pm) = obj.datetime2epoch(dateshift(ts_dt(i_pm), 'start', 'day') + hours(12));
                
            end
            
        end
        
        % Push places to database
        function pushPlacesToDB(obj, places)
            
            n = size(places,1);
            
            stmnt  = strcat("INSERT INTO places(timestamp, id, installation_id, location, dwelltime_sum, ",     ...
                "dwelltime_percentage, dwelltime_rank, uploadtime, placeloc_strength, ",           ...
                "first_dwell_starttime, last_dwell_endtime, timezone_offset) ",        ...
                "VALUES(?, ?, ?, ST_MakePoint(?,?), ?, ?, ?, ?, ?, ?, ?, ?, ?)");
           
            pstmnt  = databasePreparedStatement(obj.db_conn, stmnt);
            
            for i = 1 : n
                
                values = {places.timestamp(i), places.id(i), string(cell2mat(places.installation_id(i))),    ...
                    places.lon(i), places.lat(i), -1, -1, -1, places.uploadtime(i), ...
                    -1, -1, -1, places.timezone_offset(i)};
                
                pstmnt  = bindParamValues(pstmnt, [1:13], values);
                obj.db_conn.execute(pstmnt);
                
            end
            
        end
        
        % Push dwells to database
        function pushDwellsToDB(obj, dwells)
                       
            n = size(dwells,1);
            
            stmnt  = strcat("INSERT INTO dwells(start_ts, end_ts, id, installation_id, place_id, ",      ...
                "uploadtime, origin_of_route, destination_of_route, timezone_offset) ",                                    ...
                "VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)");
           
            pstmnt  = databasePreparedStatement(obj.db_conn, stmnt);
            
            for i = 1 : n
                
                values = {dwells.start_ts(i), dwells.end_ts(i), dwells.id(i), string(cell2mat(dwells.installation_id(i))),    ...
                    dwells.place_id(i), dwells.uploadtime(i), ...
                    dwells.origin_of_route(i), dwells.destination_of_route(i), dwells.timezone_offset(i)};
                
                pstmnt  = bindParamValues(pstmnt, [1:9], values);
                obj.db_conn.execute(pstmnt);
                
            end
            
        end
        
        % Push routes to database
        function pushRoutesToDB(obj, routes)
            
            n = size(routes,1);
            
            stmnt  = strcat("INSERT INTO routes(start_ts, end_ts, id, segment_id, installation_id, ",       ...
                "distance, gis_distance, duration, start_place, end_place, start_dwell, end_dwell, ",           ...
                "origin_timezone_offset, destination_timezone_offset, uploadtime) ",                                        ...
                "VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
           
            pstmnt  = databasePreparedStatement(obj.db_conn, stmnt);
            
            for i = 1 : n
                
                values = {routes.start_ts(i), routes.end_ts(i), routes.id(i), routes.segment_id(i), string(cell2mat(routes.installation_id(i))),    ...
                    routes.distance(i), routes.gis_distance(i), routes.duration(i), routes.start_place(i), routes.end_place(i), routes.start_dwell(i), ...
                    routes.end_dwell(i), routes.origin_timezone_offset(i), routes.destination_timezone_offset(i), routes.uploadtime(i),
                    };
                
                pstmnt  = bindParamValues(pstmnt, [1:15], values);
                obj.db_conn.execute(pstmnt);
                
            end

        end
        
        % Push legs to database
        function pushLegsToDB(obj, legs)
            
            n = size(legs,1);
            
            stmnt  = strcat("INSERT INTO legs(start_ts, end_ts, id, transport_mode, installation_id, ",         ...
                "distance, duration, match_confidence, route_id, ",                         ...
                "origin_timezone_offset, destination_timezone_offset, uploadtime, first_location, last_location) ", ...
                "VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ST_MakePoint(?,?), ST_MakePoint(?,?))");
           
            pstmnt  = databasePreparedStatement(obj.db_conn, stmnt);
            
            for i = 1 : n
                
                values = {legs.start_ts(i), legs.end_ts(i), legs.id(i), legs.transport_mode(i), string(cell2mat(legs.installation_id(i))),    ...
                    legs.distance(i), legs.duration(i), string(cell2mat(legs.match_confidence(i))), legs.route_id(i), ...
                    legs.origin_timezone_offset(i), legs.destination_timezone_offset(i), legs.uploadtime(i), ...
                    legs.firstloc_lon(i), legs.firstloc_lat(i), legs.lastloc_lon(i), legs.lastloc_lat(i)};
                
                pstmnt  = bindParamValues(pstmnt, [1:16], values);
                obj.db_conn.execute(pstmnt);
                
            end
            
        end
        
        % Push waypoints to database
        function pushWaypointsToDB(obj, waypoints)
            
            n = size(waypoints,1);
            
            stmnt  = strcat("INSERT INTO waypoints(timestamp, route_id, leg_id, transport_mode, installation_id, ",       ...
                "accuracy, vaccuracy, speed, provider, timezone_offset, uploadtime, location) ", ...
                "VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ST_MakePoint(?,?))");
           
            pstmnt  = databasePreparedStatement(obj.db_conn, stmnt);
            
            for i = 1 : n
                
                values = {waypoints.timestamp(i), waypoints.route_id(i), waypoints.leg_id(i), string(waypoints.transport_mode(i)), ...
                    string(cell2mat(waypoints.installation_id(i))), waypoints.accuracy(i), waypoints.vaccuracy(i), waypoints.speed(i), ...
                    string(waypoints.provider(i)), waypoints.timezone_offset(i), waypoints.uploadtime(i), waypoints.lon(i), waypoints.lat(i)};
                
                pstmnt  = bindParamValues(pstmnt, [1:13], values);
                obj.db_conn.execute(pstmnt);
                
            end
            
        end
        
        % Push reverse geocode details to database
        function pushRGeoToDB(obj, rgeo)
           
            n = size(rgeo, 1);
            for i = 1:n
               
                if isempty(rgeo.country{i})
                    rgeo.country(i) = {''};
                end
                
                if isempty(rgeo.county{i})
                    rgeo.county(i) = {''};
                end
                
                if isempty(rgeo.city{i})
                    rgeo.city(i) = {''};                  
                end
                
                if isempty(rgeo.district{i})
                    rgeo.district(i) = {''};
                end
                
                if isempty(rgeo.postalcode{i})
                    rgeo.postalcode(i) = {''};
                end
                
                if isempty(rgeo.street{i})
                    rgeo.street(i) = {''};
                end
                
            end
            
            obj.db_conn.sqlwrite("reverse_geocode", rgeo);
        end
    end
    
end

