# Obfuscation Tool

Java code methods to estimate privacy category of places and travels.

## LICENSE

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## General definitions

OBS! The Java code shared with this project is not stand-alone and requires generating places and travels first.

Developers seeking to take advantage of this part of the code are suggested to create an interface between their model of user travels and places with the model provided in the attached java code. Alternatively, the logic of how privacy score is derived can be copied from the library and re-implemented to suit other existing projects.


Our privacy relies on matching places to POIs using [HERE place matching](https://developer.here.com/documentation/geocoding-search-api/dev_guide/index.html "HERE Place Matchin").


The project includes a list of all HERE categories along with estimated privacy ratings and typical visit durations. Current values reflect our estimates and project requirements, and can be freely modified to suit other project specifications.

#### Sensitivity category has a range of 1-3, where:

- 1: Public
- 2: Sensitive
- 3: Private

#### Visit durations has a range of 1-4, where:

- 1: Brief (under 30 minutes)
- 2: Visit (30 minutes to 2 hours)
- 3: Stay (Over 2 hours)
- 4: Sleep (Over 4 hours and during night time)

## Package description

*model* package contains required model structures for privacy estimation. These classes are used by the privacy estimation methods and contain required fields for place and travel privacy estimation. 

*tools* package contains helper methods for different tasks used for privacy estimation.

*obfuscation* package contains the actual methods used to derive privacy ratings for places and travels.