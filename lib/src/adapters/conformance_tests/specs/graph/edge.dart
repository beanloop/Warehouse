library warehouse.test.conformance.graph.edge;

import 'package:guinness/guinness.dart';
import 'package:unittest/unittest.dart' show expectAsync;
import 'package:warehouse/adapters/base.dart';
import 'package:warehouse/graph.dart';
import 'package:warehouse/src/adapters/conformance_tests/graph_domain.dart';
import 'package:warehouse/src/adapters/conformance_tests/factories.dart';

runEdgeTests(SessionFactory factory) {
  describe('edge objects', () {
    GraphDbSession session;
    Person abbington, armitage, freeman, mcKellen;
    Partnership abbingtonFreeman;
    Role bilbo, gandalf, thorin;
    Movie avatar, theHobbit;

    beforeEach(() async {
      session = factory();

      abbington = new Actor()..name = 'Amanda Abbington';
      armitage = new Actor()..name = 'Richard Armitage';
      freeman = new Actor()..name = 'Martin Freeman';
      mcKellen = new Actor()..name = 'Ian McKellen';

      abbingtonFreeman = new Partnership()
        ..partners = [abbington]
        ..started = new DateTime.utc(2000);

      bilbo = new Role()..role = 'Bilbo' ..actor = freeman;
      gandalf = new Role()..role = 'Gandalf' ..actor = mcKellen;
      thorin = new Role()..role = 'Thorin' ..actor = armitage;

      avatar = new Movie()
        ..title = 'Avatar'
        ..releaseDate = new DateTime.utc(2009, 12, 18);

      theHobbit = new Movie()
        ..title = 'The Hobbit: An Unexpected Journey'
        ..releaseDate = new DateTime.utc(2012, 12, 12)
        ..genres = ['adventure']
        ..rating = 8.0
        ..cast = [bilbo, gandalf];

      session.store(abbington);
      session.store(armitage);
      session.store(freeman);
      session.store(mcKellen);
      session.store(theHobbit);
      await session.saveChanges();
    });

    it('should throw if the end of the relation have not been stored', () async {
      avatar.director = new Director()..name = 'James Cameron';
      expect(() => session.store(avatar)).toThrowWith(type: StateError);
    });

    it('should get edge objects', () async {
      var get = await session.get(session.entityId(theHobbit));

      expect(get).toBeA(Movie);
      expect(get.title).toEqual('The Hobbit: An Unexpected Journey');

      for (var role in get.cast) {
        expect(role).toBeA(Role);
        expect(role.movie).toBe(get);
        expect(role.actor).toBeA(Actor);
        expect(role.actor.roles).toContain(role);
      }

      expect(get.cast.map((role) => role.role).toList()..sort()).toEqual(['Bilbo', 'Gandalf']);
    });

    it('should be able to add new edges', () async {
      theHobbit.cast.add(thorin);
      session.store(theHobbit);
      await session.saveChanges();

      var get = await session.get(session.entityId(theHobbit));

      for (var role in get.cast) {
        expect(role).toBeA(Role);
        expect(role.movie).toBe(get);
        expect(role.actor).toBeA(Actor);
        expect(role.actor.roles).toContain(role);
      }

      expect(get.cast.map((role) => role.role).toList()..sort()).toEqual(
          ['Bilbo', 'Gandalf', 'Thorin']
      );
    });

    it('should be able to remove edges', () async {
      theHobbit.cast.remove(gandalf);
      session.store(theHobbit);
      await session.saveChanges();

      var get = await session.get(session.entityId(theHobbit));

      for (var role in get.cast) {
        expect(role).toBeA(Role);
        expect(role.movie).toBe(get);
        expect(role.actor).toBeA(Actor);
        expect(role.actor.roles).toContain(role);
      }

      expect(get.cast.map((role) => role.role)).toEqual(['Bilbo']);
    });

    it('should be able to remove all edges', () async {
      theHobbit.cast = null;
      session.store(theHobbit);
      await session.saveChanges();

      var get = await session.get(session.entityId(theHobbit));
      expect(get.cast).toBeNull();
    });

    it('should be able to delete an edge by deleting the edge itself', () async {
      session.delete(bilbo);
      await session.saveChanges();

      var get = await session.get(session.entityId(theHobbit));
      expect(get.cast.map((role) => role.role).toList()..sort()).toEqual(['Gandalf']);
    });

    it('should be able to update an edge', () async {
      gandalf.role = 'Gandalf the grey';
      session.store(gandalf);
      await session.saveChanges();

      var get = await session.get(session.entityId(theHobbit));
      expect(get.cast.map((role) => role.role).toList()..sort()).toEqual(
          ['Bilbo', 'Gandalf the grey']
      );
    });

    it('should validate the edge before it is created', () {
      theHobbit.cast.add(new Role());
      expect(() => session.store(theHobbit)).toThrowWith(type: ValidationError);
    });

    it('should validate the edge before it is updated', () {
      expect(() => session.store(gandalf..role = null)).toThrowWith(type: ValidationError);
    });

    it('should fire events after an edge is created', () async {
      theHobbit.cast.add(thorin);
      session.store(theHobbit);

      session.onOperation.skip(1).listen(expectAsync((operation) {
        expect(operation).toBeA(EdgeOperation);
        expect(operation.id).toEqual(session.entityId(thorin));
        expect(operation.type).toBe(OperationType.create);
        expect(operation.entity).toBe(thorin);
        expect(operation.tailNode).toBe(theHobbit);
        expect(operation.headNode).toBe(armitage);
        expect(operation.label).toEqual('cast');
      }));
      session.onCreated.listen(expectAsync((operation) {
        expect(operation).toBeA(EdgeOperation);
        expect(operation.id).toEqual(session.entityId(thorin));
        expect(operation.type).toBe(OperationType.create);
        expect(operation.entity).toBe(thorin);
        expect(operation.tailNode).toBe(theHobbit);
        expect(operation.headNode).toBe(armitage);
        expect(operation.label).toEqual('cast');
      }));
      session.onUpdated.skip(1).listen((_) => throw 'should not be called');
      session.onDeleted.listen((_) => throw 'should not be called');

      await session.saveChanges();
    });

    it('should fire events after an edge is updated', () async {
      gandalf.role = 'Gandalf the grey';
      session.store(gandalf);

      session.onOperation.listen(expectAsync((operation) {
        expect(operation).toBeA(EdgeOperation);
        expect(operation.id).toEqual(session.entityId(gandalf));
        expect(operation.type).toBe(OperationType.update);
        expect(operation.entity).toBe(gandalf);
      }));
      session.onUpdated.listen(expectAsync((operation) {
        expect(operation).toBeA(EdgeOperation);
        expect(operation.id).toEqual(session.entityId(gandalf));
        expect(operation.type).toBe(OperationType.update);
        expect(operation.entity).toBe(gandalf);
      }));
      session.onCreated.listen((_) => throw 'should not be called');
      session.onDeleted.listen((_) => throw 'should not be called');

      await session.saveChanges();
    });

    it('should fire events after an edge is deleted', () async {
      theHobbit.cast.remove(gandalf);
      session.store(theHobbit);

      session.onOperation.skip(1).listen(expectAsync((operation) {
        expect(operation).toBeA(EdgeOperation);
        expect(operation.id).toEqual(session.entityId(gandalf));
        expect(operation.type).toBe(OperationType.delete);
      }));
      session.onDeleted.listen(expectAsync((operation) {
        expect(operation).toBeA(EdgeOperation);
        expect(operation.id).toEqual(session.entityId(gandalf));
        expect(operation.type).toBe(OperationType.delete);
      }));
      session.onCreated.listen((_) => throw 'should not be called');
      session.onUpdated.skip(1).listen((_) => throw 'should not be called');

      await session.saveChanges();
    });

    it('should fire events after an edge is deleted by deleting the edge itself', () async {
      var id = session.entityId(bilbo);
      session.delete(bilbo);

      session.onOperation.listen(expectAsync((operation) {
        expect(operation).toBeA(EdgeOperation);
        expect(operation.id).toEqual(id);
        expect(operation.type).toBe(OperationType.delete);
        expect(operation.entity).toBe(bilbo);
      }));
      session.onDeleted.listen(expectAsync((operation) {
        expect(operation).toBeA(EdgeOperation);
        expect(operation.id).toEqual(id);
        expect(operation.type).toBe(OperationType.delete);
        expect(operation.entity).toBe(bilbo);
      }));
      session.onCreated.listen((_) => throw 'should not be called');
      session.onUpdated.listen((_) => throw 'should not be called');

      await session.saveChanges();
    });

    it('should support undirected edges', () async {
      freeman.friends = [mcKellen];
      session.store(freeman);
      await session.saveChanges();

      var get = await session.get(session.entityId(freeman));

      expect(get.friends.map((friend) => friend.name)).toEqual(['Ian McKellen']);
      expect(get.friends[0].friends.map((friend) => friend.name)).toEqual(['Martin Freeman']);
      expect(get.friends[0].friends[0]).toBe(get);

      get = await session.get(session.entityId(mcKellen));

      expect(get.friends.map((friend) => friend.name)).toEqual(['Martin Freeman']);
      expect(get.friends[0].friends.map((friend) => friend.name)).toEqual(['Ian McKellen']);
      expect(get.friends[0].friends[0]).toBe(get);
    });

    it('should support undirected edges with Edge objects', () async {
      freeman.partnerships = [abbingtonFreeman];
      session.store(freeman);
      await session.saveChanges();

      var get = await session.get(session.entityId(freeman));

      expect(get.partnerships.length).toEqual(1);
      expect(get.partnerships[0].started).toEqual(new DateTime.utc(2000));
      expect(get.partnerships[0].partners.length).toEqual(2);

      get.partnerships[0].partners.forEach((partner) {
        expect(partner.partnerships.length).toEqual(1);
        expect(partner.partnerships[0]).toBe(get.partnerships[0]);
      });

      expect(get.partnerships[0].partners.map((person) => person.name).toList()..sort()).toEqual(
          ['Amanda Abbington', 'Martin Freeman']
      );

      get = await session.get(session.entityId(abbington));

      expect(get.partnerships.length).toEqual(1);
      expect(get.partnerships[0].started).toEqual(new DateTime.utc(2000));
      expect(get.partnerships[0].partners.length).toEqual(2);

      get.partnerships[0].partners.forEach((partner) {
        expect(partner.partnerships.length).toEqual(1);
        expect(partner.partnerships[0]).toBe(get.partnerships[0]);
      });

      expect(get.partnerships[0].partners.map((person) => person.name).toList()..sort()).toEqual(
          ['Amanda Abbington', 'Martin Freeman']
      );
    });

    it('should not create duplicates of undirected edges', () async {
      freeman.friends = [mcKellen];
      mcKellen.friends = [freeman];
      session.store(freeman);
      await session.saveChanges();
      session.store(mcKellen);
      await session.saveChanges();

      var get = await session.get(session.entityId(freeman));

      expect(get.friends.map((friend) => friend.name)).toEqual(['Ian McKellen']);
      expect(get.friends[0].friends.map((friend) => friend.name)).toEqual(['Martin Freeman']);
      expect(get.friends[0].friends[0]).toBe(get);

      get = await session.get(session.entityId(mcKellen));

      expect(get.friends.map((friend) => friend.name)).toEqual(['Martin Freeman']);
      expect(get.friends[0].friends.map((friend) => friend.name)).toEqual(['Ian McKellen']);
      expect(get.friends[0].friends[0]).toBe(get);
    });
  });
}
