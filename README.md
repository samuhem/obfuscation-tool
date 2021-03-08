# Obfuscation Tool

*V1.0*

The main code base is written in Matlab and is found under @Obfuscation older. Place and travel sensitivity estimation is written in Java and found under obfuscation-java folder.

## LICENSE

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## General definitions

The Matlab obfuscation tool connects to an external database, processes data to hide sensitive information about user's places and travels, and then outputs obfuscated data to another external database. Both databases are expected to contain specific data structures, specified in the db_schemas.txt file. Deviations from the expected data structures requires changing the matlab code to match the altered data structures.

The Java code provided along with this project details on how to derive privacy score for places and travels. Note that the java code is detached from a larger project and is not standalone. Developers seeking to take advantage of this part of the code are suggested to create an interface between their model of user travels and places with the model provided in the attached java code. Alternatively, the logic of how privacy score is derived can be copied from the library and re-implemented to suit other existing projects.

### Expected Travels Format

![Travel Data Format](https://github.com/travelai-public/anonymization-tool/blob/main/docs/travelai-overview.png)

The obfuscation tool expect travels data in specific format, using five different travel object definitions:

#### Routes
Route is defined as a single transportation period taken in order to transit between origin and destination, i.e., between Places A and B. Typical example Routes include transporting from home to work, or from work to lunch place. Route consists of one or more Legs.

#### Legs
Leg is defined as a transportation period with a single transportation mode. If one was talking in terms of transport or network graphs, a leg would be an edge, while stops or stations in graph theory are called nodes. Example Legs include bus or train journey, walking from office to station or cycling from home to office. Legs should have a privacy rating as defined in the privacy subsection below.

#### Waypoints
Waypoint is a geolocation container that can include additional details such as transportation mode, time, accuracy, and velocity.

#### Places
Place is defined as a location where a user spends significant amounts of time, and often includes a meaningful real-world correspondence. Example Places include user-specific locations such as home and office, or public areas such as shopping malls and parks. Places should include a privacy rating as defined in the privacy subsection

#### Dwells
Dwells are individual visits to a place, for example a single visit to a shop. Dwells store information about start and end times of the visit.

#### Reverse Geocode
Reverse geocode store address information for places.

### Database Format

The software expects the following structure for the input database:
 
#### public.routes
- id integer,  
- installation_id text,  
- start_ts bigint,  
- end_ts bigint,  
- distance real,
- gis_distance real,
- duration integer,
- start_place integer,
- end_place integer,
- start_dwell integer,
- end_dwell integer,
- data_quality text,
- match_confidence real,
- segment_id integer

#### public.legs
- id integer,  
- installation_id text,  
- start_ts bigint,  
- end_ts bigint,  
- transport_mode integer,
- distance real,
- duration real,
- match_confidence real,
- route_id integer,
- first_location geometry,
- last_location geometry
- privacy_sensitivity

#### public.waypoints
- installation_id text,
- route_id integer,
- gisleg_id integer,
- timestamp bigint,
- transport_mode integer,
- location geometry,
- accuracy real,
- vaccuracy real,
- speed real,
- provider integer

#### public.places
- timestamp bigint,
- id integer,
- installation_id text,
- location geometry,
- dwelltime_sum real,
- dwelltime_percentage real,
- dwelltime_rank integer,
- label text,
- placeloc_strength real,
- first_dwell_starttime bigint,
- last_dwell_endtime bigint,
- privacy_sensitivity

#### public.dwells
- timestamp bigint,
- id integer,
- installation_id text,
- start_ts bigint,  
- end_ts bigint,  
- duration real,
- place_id integer,
- origin_of_route integer,
- destination_of_route integer,
- uploadtime

### Privacy sensitivity

Places and legs contain a field 'privacy_sensitivity' which is used to store resolved privacy category of legs and places. 

Privacy category is enumeration of four possible values:

- 0: Unknown
- 1: Public
- 2: Sensitive
- 3: Privacy

Populating these fields is done in the process that outputs data into the input_db database. Our methods for calculating privacy score and privacy category can be found from the java obfuscation code, specifically from uk.co.travelai_public.obfuscation.PlaceSensitivity and uk.co.travelai_public.obfuscation.TravelSensitivity.

## Installation Instructions

### Database Settings

The matlab obfuscation class connects to two databases, input_db and output_db. Former is used to load unprocessed data about users' places and travels, and latter is used to store processed and obfuscated data. The databases will require setting up a matlab datasource that contains connection details, see https://se.mathworks.com/help/database/ug/configuring-driver-and-data-source.html for details. 

Once datasource is set, rest of the connection details are set in the Obfuscation class constants:

- indb_datasource
- indb_username
- indb_password
- outdb_datasource
- outdb_username
- outdb_password 

### Obfuscation Settings

There are a set of other options in the Obfuscation class variables, that can be used to configure behavior of the obfuscation process:

*obfuscate_temporal_granularity:*
Temporal obfuscation, applies to all timestamp fields. Input range is one of [0,1,2,3], where the value applies increasingly coarse filtering on data fields containing timestamps. 

- 0: Precise times,  
- 1: Hourly, 
- 2: AM/PM, 
- 3: Date.

*obf_minDist_between_waypoints_m*
Used to control reducing granularity of legs deemed sensitive. The value reduces waypoints of sensitive legs to resolution of input meters.

*obf_minDuration_between_waypoints_ms:*
Used to control reducing granularity of legs deemed sensitive. The value reduces waypoints of sensitive legs to resolution of input milliseconds.
 
## Usage

After setting up input and export database settings, Obfuscation can be run by first initializing the class using:

```obf = Obfuscation();```

Time range for the obfuscation process can then be set with:

```obf = obf.setQueryTS(epoch_start_ms, epoch_end_ms)```

, where first parameter is the start epoch timestamp in milliseconds and second parameter is the end epoch timestamp in milliseconds.

The main pipelin can then be run with:

```obf.run(userId);```

After running the main obfuscation, it is recommended that results are visually checked, using the functions detailed in next section, to perform at expected obfuscation level. Results are then exported to output database with:

```obf = obf.connectToOutputDB();```
```obf = obf.pushObfuscatedData();```

## Visualisation

Obfuscation class containing a set of methods to visualise travel data before and after obfuscation process.

```plotPlaces():```

Plots (exact) location of each Place in the class data.

```plotRoute(routeId, obfuscation):```

Plot route pointed by input routeId. The second parameter controls wether to plot unprocessed route (0), obfuscated route (1), or both versions (2).

```plotRoutesWithPrivacyCategory(obj, privacyCat, routeIDs):```

Plot all routes pointed input input routeIDs matching input privacy category.

```plotLeg(legId, obfuscation):```

Plot leg pointed by legId. The second parameter controls wether to plot unprocessed leg (0), obfuscated leg (1), or both versions (2).

```plotProtectedAreas():```

Plots all places in the class data, along with each places' mapped protected areas.

```plotProtectedArea(area):```

Plot polygon and its name contained by input area.

```plotHiddenWaypoints():```

Plot all waypoints marked as hidden.

```plotWaypoints(waypoints):```

Plot input waypoints.

## Output

Output is exported to another database defined by a set of DB_OUT parameters
