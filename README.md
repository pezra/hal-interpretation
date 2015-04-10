[![Build Status](https://travis-ci.org/pezra/hal-interpretation.png?branch=master)](https://travis-ci.org/pezra/hal-interpretation)
[![Code Climate](https://codeclimate.com/github/pezra/hal-interpretation.png)](https://codeclimate.com/github/pezra/hal-interpretation)

# HalInterpretation

Build ActiveModels from HAL documents with good error messages
for validity issues.

## Usage

`HalInterpretation` provides a DSL for declaring how to build one or
more `ActiveModel` objects from a HAL document.

```ruby
class UserHalInterpreter
  include HalInterpretation

  item_class User

  # Extract value of the name member of the JSON object and assign it to
  # the `name` attribute of the model.
  extract :name

  # Extract the value of the line1 member of the address member of the JSON
  # object and assign it to the `address_line` attribute of the model.
  extract :address_line, from: "address/line1"

  # Assign the `seq` attribute of the model a newly generated sequence number.
  extract :seq, with: ->(_hal_repr) { next_seq_num }

  # Extract the birthday member of the JSON object, convert it to a ruby date
  # and assign it to the `birthday` attribute of the model.
  extract :birthday, coercion: ->(date_str) { Date.iso8601(date_str) }

  # Extract the targets of the .../knows links, extract the ids from each and
  # assign those ids to the `friend_ids` attribute of the model.
  extract_links :friend_ids, coercion: ->(urls) { urls.map{|u| u.split("/").last} },
    rel: "http://xmlns.com/foaf/0.1/knows"

  # Extract the target of the up link and assign the full url to the up
  # attribute of the model. Reports a problem if more than one link of this
  # type is present.
  extract_link  :up

  # Extract the target of the rel link and assign a HAL representation to the person
  # attribute of the model. Reports a problem if more than one link of this
  # type is present.
  extract_repr  :profile, rel: "http://xmlns.com/foaf/0.1/Person",
    coercion: ->(profile_repr) { CustomInterpretation.new(profile_repr) }

  # Extract the target of the rel link and assign a HAL representation
  # set to the cohorts attribute of the model. Reports a problem if
  # more than one link of this type is present.
  extract_reprs  :cohorts, rel: "http://xmlns.com/foaf/0.1/knows",
    coercion: ->(cohort_repr_set) {
      cohort_repr_set.map {|repr| CustomInterpretation.new(repr) }
    }

  def initialize
    @cur_seq_num = 0
  end

  protected

  def next_seq_num
    @cur_seq_num += 1
  end
end
```

This interpreter will work for documents that look like the following

```json
{ "name": "Bob",
  "address": {
    "line1": "123 Main St",
    "city":  "Denver"
  },
  "birthday": "1980-08-31",
  "_links": {
    "http://xmlns.com/foaf/0.1/Person": { "href": "http://example.com/bob" },
    "http://xmlns.com/foaf/0.1/knows": [
      { "href": "http://example.com/alice" },
      { "href": "http://example.com/mallory" }
    ],
    "up": { "href": "http://example.com/vips" }
} }
```

or

```json
{ "_embedded": {
    "item": [
      { "name": "Bob",
        "address": {
          "line1": "123 Main St",
          "city":  "Denver"
        },
        "birthday": "1980-08-31",
        "_links": {
          "http://xmlns.com/foaf/0.1/Person": { "href": "http://example.com/bob" },
          "http://xmlns.com/foaf/0.1/knows": [
            { "href": "http://example.com/alice" },
            { "href": "http://example.com/mallory" }
          ],
          "up": { "href": "http://example.com/vips" }
      } },

      { "name": "Alice",
        "address": {
          "line1": "123 Main St",
          "city":  "Denver"
        },
        "birthday": "1979-02-16",
        "_links": {
          "http://xmlns.com/foaf/0.1/Person": { "href": "http://example.com/alice },
          "http://xmlns.com/foaf/0.1/knows": [
            { "href": "http://example.com/bob" },
            { "href": "http://example.com/mallory" }
          ],
          "up": { "href": "http://example.com/vips" }
      } }
    ]
} }

```

#### Create

To interpret a HAL document simply create a new interpreter from the
JSON document to interpret and then call its `#items` method.

```ruby
class Users < ApplicationController
  def create
    @users = UserHalInterpreter.new_from_json(request.raw_post).items

    @users.each(&:save!)

  rescue HalInterpretation::InvalidRepresentationError => err
    render template: "shared/error", status: 422, locals: { problems: err.problems }
  end
end
```

The `items` method returns an `Enumerable` of valid `item_class` objects.

#### Update

To update an existing record

```ruby

class Users < ApplicationController
  def update
    existing_user = User.find(params[:id])

    @user = UserHalInterpreter.new_from_json(request.raw_post).only_update(existing_user)
              .item

    @user.save!

  rescue HalInterpretation::InvalidRepresentationError => err
    render template: "shared/error", status: 422, locals: { problems: err.problems }
  end
end
```

This approach with produce an error if the JSON contains more than one
representation.

### Errors

 If the JSON being interpreted is invalid or malformed
`HalInterpretation` provides a list of the problems encountered
through the `#problems` method. Each problem message includes a
[JSON pointer][] to the exact location in the original document that
caused the problem. This is true even when interpreting
[collections][] for example if name of the third user in a collection
is null the problem message would be

    /_embedded/item/2/name cannot be blank

Validity is determined using the `#valid?` method of the models being
built.


## Installation

Add this line to your application's Gemfile:

    gem 'hal-interpretation'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hal-interpretation

## Contributing

1. Fork it ( http://github.com/pezra/hal-interpretation/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Make your improvement
4. Update the version following [semver][] rules
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create new Pull Request


[semver]: http://semver.org/
[json pointer]: http://tools.ietf.org/html/rfc6901
[collections]: https://tools.ietf.org/html/rfc6573
